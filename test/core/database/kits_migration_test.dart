import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'migrazione 12→13 conserva i viaggi e aggiunge transports null',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'packlog-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/inventory.sqlite');

      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement("""
        INSERT INTO houses (id,name,is_primary,created_at,updated_at,user_id,sync_status)
        VALUES ('h1','Casa',1,1700000000,1700000001,'u1',0)
      """);
      await seed.customStatement("""
        INSERT INTO trips (id,name,destination_house_id,is_saved,legs,created_at,updated_at,user_id,sync_status)
        VALUES ('t1','Toscana','h1',1,'[]',1700000000,1700000001,'u1',2)
      """);
      await seed.customStatement("""
        INSERT INTO trips (id,name,is_saved,created_at,updated_at,user_id,sync_status)
        VALUES ('t2','Weekend',0,1700000000,1700000001,'u1',1)
      """);
      Future<List<Map<String, Object?>>> read(
        AppDatabase d,
        String table,
      ) async =>
          (await d.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((r) => Map<String, Object?>.of(r.data)..remove('transports'))
              .toList();
      final tripsBefore = await read(seed, 'trips');
      final housesBefore = await read(seed, 'houses');
      await seed.close();

      // Riporta il file alla forma v12: niente kit, niente transports.
      final raw = sqlite3.open(file.path);
      try {
        raw.execute('''
          DROP TABLE kit_items;
          DROP TABLE kits;
          ALTER TABLE trips DROP COLUMN transports;
          PRAGMA user_version = 12;
        ''');
      } finally {
        raw.dispose();
      }

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 13);
      expect(await read(migrated, 'trips'), tripsBefore);
      expect(await read(migrated, 'houses'), housesBefore);
      final trips = await migrated
          .customSelect('SELECT transports FROM trips')
          .get();
      expect(trips, hasLength(2));
      expect(trips.every((r) => r.data['transports'] == null), isTrue);

      // Le tabelle nuove esistono, con i loro indici, e sono usabili.
      await migrated.kitsDao.watchKitsOfHouse('h1').first;
      final indexes = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_kit%'",
          )
          .get();
      expect(
        indexes.map((r) => r.data['name']),
        containsAll([
          'idx_kits_house_id',
          'idx_kit_items_kit_id',
          'idx_kit_items_item_id',
        ]),
      );
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .data['user_version'],
        13,
      );
    },
  );
}
