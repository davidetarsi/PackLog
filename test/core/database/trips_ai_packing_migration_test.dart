import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v11 → v12 conserva viaggi con tappe, oggetti e bagagli, con le colonne AI a null',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'packlog-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/inventory.sqlite');

      // Dati scritti con lo schema corrente, poi riportati alla forma v11
      // togliendo solo le due colonne introdotte dalla v12.
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement("""
        INSERT INTO houses (id,name,is_primary,location_city,location_lat,location_lon,created_at,updated_at,user_id,sync_status,sync_retry_count,last_sync_error,last_synced_at)
        VALUES ('h1','Casa',1,'Roma',41.9,12.5,1700000000,1700000001,'u1',2,3,'offline',1700000000)
      """);
      await seed.customStatement("""
        INSERT INTO trips (id,name,destination_house_id,location_city,is_saved,legs,created_at,updated_at,user_id,sync_status)
        VALUES ('t1','Toscana','h1','Roma',1,'[{"id":"leg-1","location_display_name":"Firenze"}]',1700000000,1700000001,'u1',2)
      """);
      await seed.customStatement("""
        INSERT INTO trips (id,name,is_saved,legs,created_at,updated_at,user_id,sync_status)
        VALUES ('t2','Weekend',0,'[]',1700000000,1700000001,'u1',1)
      """);
      await seed.customStatement("""
        INSERT INTO trip_item_entries (id,trip_id,name,category,quantity,origin_house_id,is_checked)
        VALUES ('i1','t1','Magliette','vestiti',2,'h1',1)
      """);
      await seed.customStatement("""
        INSERT INTO luggages (id,name,size_type,created_at,updated_at)
        VALUES ('l1','Zaino','cabinBaggage',1700000000,1700000001)
      """);
      await seed.customStatement(
        "INSERT INTO trip_luggage_entries (trip_id,luggage_id) VALUES ('t1','l1')",
      );
      const tables = [
        'houses',
        'trips',
        'trip_item_entries',
        'luggages',
        'trip_luggage_entries',
      ];
      const aiColumns = {'ai_packing_setup', 'ai_packing_result'};
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] =
            (await seed
                    .customSelect('SELECT * FROM $table ORDER BY rowid')
                    .get())
                .map(
                  (r) =>
                      Map<String, Object?>.of(r.data)
                        ..removeWhere((k, _) => aiColumns.contains(k)),
                )
                .toList();
      }
      await seed.close();

      final raw = sqlite3.open(file.path);
      try {
        raw.execute('''
          ALTER TABLE trips DROP COLUMN ai_packing_setup;
          ALTER TABLE trips DROP COLUMN ai_packing_result;
          PRAGMA user_version = 11;
        ''');
      } finally {
        raw.dispose();
      }

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 12);
      for (final table in tables) {
        final after =
            (await migrated
                    .customSelect('SELECT * FROM $table ORDER BY rowid')
                    .get())
                .map(
                  (r) =>
                      Map<String, Object?>.of(r.data)
                        ..removeWhere((k, _) => aiColumns.contains(k)),
                )
                .toList();
        expect(
          after,
          before[table],
          reason: 'Dati di $table devono restare identici dalla v11',
        );
      }
      final trips = await migrated
          .customSelect('SELECT ai_packing_setup, ai_packing_result FROM trips')
          .get();
      expect(trips, hasLength(2));
      for (final row in trips) {
        expect(row.data['ai_packing_setup'], isNull);
        expect(row.data['ai_packing_result'], isNull);
      }
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .data['user_version'],
        12,
      );
    },
  );
}
