import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';

void main() {
  for (final version in [8, 9, 10]) {
    test(
      'v$version → v11 conserva inventario, viaggi e sync senza bagagli',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'packlog-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/inventory.sqlite');
        final old = AppDatabase.forTesting(NativeDatabase(file));
        // Le tabelle non cambiate nella v11 conservano lo schema storico.
        // Si rimuovono sotto le colonne assenti nella versione di partenza.
        await old.customStatement("""
        INSERT INTO houses (id,name,is_primary,location_city,location_lat,location_lon,created_at,updated_at,user_id,sync_status,sync_retry_count,last_sync_error,last_synced_at)
        VALUES ('h1','Casa',1,'Roma',41.9,12.5,1700000000,1700000001,'u1',2,3,'offline',1700000000)
      """);
        await old.customStatement("""
        INSERT INTO spaces (id,house_id,name,icon_name,created_at,updated_at,user_id)
        VALUES ('s1','h1','Armadio','door_sliding',1700000000,1700000001,'u1')
      """);
        await old.customStatement("""
        INSERT INTO items (id,house_id,space_id,name,category,quantity,description,created_at,updated_at,user_id,sync_status,next_sync_attempt_at)
        VALUES ('i1','h1','s1','Magliette','vestiti',7,'Blu',1700000000,1700000001,'u1',2,1700000050)
      """);
        await old.customStatement("""
        INSERT INTO items (id,house_id,name,category,quantity,created_at,updated_at,user_id,is_deleted,sync_status)
        VALUES ('deleted','h1','Tombstone','varie',1,1700000000,1700000001,'u1',1,2)
      """);
        for (final id in ['t1', 't2']) {
          await old.customStatement(
            """
          INSERT INTO trips (id,name,destination_house_id,location_city,is_saved,created_at,updated_at,user_id,sync_status)
          VALUES (?,'Viaggio','h1','Roma',1,1700000000,1700000001,'u1',2)
        """,
            [id],
          );
          // Stesso oggetto in due viaggi: snapshot distinti e già spuntati.
          await old.customStatement(
            """
          INSERT INTO trip_item_entries (id,trip_id,name,category,quantity,origin_house_id,is_checked)
          VALUES ('i1',?,'Nome snapshot','vestiti',2,'h1',1)
        """,
            [id],
          );
        }
        if (version >= 9) {
          await old.customStatement(
            """UPDATE items SET ai_metadata = '{"color":"blue"}' WHERE id = 'i1'""",
          );
        }
        if (version >= 10) {
          await old.customStatement(
            "UPDATE trips SET legs = '[]' WHERE id = 't1'",
          );
        }
        const tables = [
          'houses',
          'spaces',
          'items',
          'luggages',
          'trips',
          'trip_item_entries',
          'trip_luggage_entries',
        ];
        final before = <String, List<Map<String, Object?>>>{};
        for (final table in tables) {
          before[table] =
              (await old
                      .customSelect('SELECT * FROM $table ORDER BY rowid')
                      .get())
                  .map((r) => r.data)
                  .toList();
        }
        await old.close();
        // Ricostruisce la sola tabella cambiata nella v11, nella forma storica.
        final raw = sqlite3.open(file.path);
        try {
          raw.execute("""
          PRAGMA foreign_keys = OFF;
          DROP TABLE luggages;
          CREATE TABLE luggages (
            id TEXT PRIMARY KEY NOT NULL,
            house_id TEXT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
            name TEXT NOT NULL, size_type TEXT NOT NULL, volume_liters INTEGER,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0, last_synced_at INTEGER,
            user_id TEXT, sync_status INTEGER NOT NULL DEFAULT 1,
            sync_retry_count INTEGER NOT NULL DEFAULT 0, last_sync_error TEXT,
            sentry_trace_id TEXT, next_sync_attempt_at INTEGER
          );
          CREATE INDEX idx_luggages_house_id ON luggages(house_id);
        """);
          if (version < 9) {
            raw.execute('ALTER TABLE items DROP COLUMN ai_metadata');
          }
          if (version < 10) {
            raw.execute('ALTER TABLE trips DROP COLUMN legs');
          }
          raw.execute('PRAGMA user_version = $version');
        } finally {
          raw.dispose();
        }
        final migrated = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(migrated.close);
        for (final table in tables) {
          final after =
              (await migrated
                      .customSelect('SELECT * FROM $table ORDER BY rowid')
                      .get())
                  .map((r) => r.data)
                  .toList();
          expect(
            after,
            before[table],
            reason:
                'Dati e metadati di $table devono restare identici dalla v$version',
          );
        }
        expect(
          await migrated.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await migrated.customSelect('PRAGMA user_version').getSingle())
              .data['user_version'],
          11,
        );
      },
    );
  }

  test(
    'v10 → v11 conserva bagagli, metadati sync e collegamenti ai viaggi',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
        CREATE TABLE houses (id TEXT PRIMARY KEY);
        CREATE TABLE trips (id TEXT PRIMARY KEY);
        CREATE TABLE luggages (
          id TEXT PRIMARY KEY NOT NULL,
          house_id TEXT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
          name TEXT NOT NULL, size_type TEXT NOT NULL, volume_liters INTEGER,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0, last_synced_at INTEGER,
          user_id TEXT, sync_status INTEGER NOT NULL DEFAULT 1,
          sync_retry_count INTEGER NOT NULL DEFAULT 0, last_sync_error TEXT,
          sentry_trace_id TEXT, next_sync_attempt_at INTEGER
        );
        CREATE INDEX idx_luggages_house_id ON luggages(house_id);
        CREATE TABLE trip_luggage_entries (
          trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
          luggage_id TEXT NOT NULL REFERENCES luggages(id) ON DELETE CASCADE,
          PRIMARY KEY(trip_id,luggage_id)
        );
        INSERT INTO houses VALUES ('h1');
        INSERT INTO trips VALUES ('t1');
        INSERT INTO luggages
          (id,house_id,name,size_type,volume_liters,created_at,updated_at,user_id,sync_status,sync_retry_count,last_sync_error,last_synced_at,sentry_trace_id,next_sync_attempt_at)
          VALUES ('l1','h1','Zaino','custom',35,1700000000,1700000001,'u1',2,3,'offline',1700000002,'trace',1700000003);
        INSERT INTO trip_luggage_entries VALUES ('t1','l1');
        PRAGMA user_version = 10;
        PRAGMA foreign_keys = ON;
      ''');
          },
        ),
      );
      addTearDown(db.close);
      final row =
          (await db
                  .customSelect("SELECT * FROM luggages WHERE id = 'l1'")
                  .get())
              .first
              .data;
      expect(db.schemaVersion, 11);
      expect(row['id'], 'l1');
      expect(row['house_id'], 'h1');
      expect(row['name'], 'Zaino');
      expect(row['size_type'], 'custom');
      expect(row['created_at'], 1700000000);
      expect(row['updated_at'], 1700000001);
      final indices = await db
          .customSelect('PRAGMA index_list(luggages)')
          .get();
      expect(
        indices.any((r) => r.data['name'] == 'idx_luggages_house_id'),
        isTrue,
      );
      expect(row['user_id'], 'u1');
      expect(row['volume_liters'], 35);
      expect(row['sync_status'], 2);
      expect(row['sync_retry_count'], 3);
      expect(row['last_sync_error'], 'offline');
      expect(row['last_synced_at'], 1700000002);
      expect(row['sentry_trace_id'], 'trace');
      expect(row['next_sync_attempt_at'], 1700000003);
      await db.customStatement(
        "INSERT INTO luggages (id,name,size_type,created_at,updated_at) VALUES ('l2','Trolley','cabinBaggage',1700000000,1700000000)",
      );
      await db.customStatement("DELETE FROM houses WHERE id = 'h1'");
      expect(
        (await db
                .customSelect("SELECT house_id FROM luggages WHERE id = 'l1'")
                .getSingle())
            .data['house_id'],
        isNull,
      );
      expect(
        (await db.customSelect('SELECT * FROM trip_luggage_entries').get())
            .single
            .data['luggage_id'],
        'l1',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA foreign_keys').getSingle())
            .data['foreign_keys'],
        1,
      );
    },
  );
}
