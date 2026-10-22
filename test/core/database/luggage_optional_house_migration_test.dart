import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';

void main() {
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
