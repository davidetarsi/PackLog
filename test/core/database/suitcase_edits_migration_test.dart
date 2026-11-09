import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'migrazione 13→14 conserva i viaggi e crea la coda delle modifiche',
    () async {
      final directory = await Directory.systemTemp.createTemp('packlog-mig-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/inventory.sqlite');

      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement("""
      INSERT INTO trips (id,name,is_saved,created_at,updated_at,user_id,sync_status)
      VALUES ('t1','Weekend',0,1700000000,1700000001,'u1',1)
    """);
      await seed.close();

      // Riporta il file alla forma v13: senza la coda.
      final raw = sqlite3.open(file.path);
      try {
        raw.execute('''
        DROP TABLE suitcase_edits;
        PRAGMA user_version = 13;
      ''');
      } finally {
        raw.dispose();
      }

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 14);
      final trips = await migrated.customSelect('SELECT id FROM trips').get();
      expect(trips.map((r) => r.data['id']), ['t1']);
      expect(await migrated.suitcaseEditsDao.pending(), isEmpty);
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .data['user_version'],
        14,
      );
    },
  );
}
