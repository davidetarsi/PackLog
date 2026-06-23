import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for LuggagesDao sync surface (P1 contracts).
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('LuggagesDao - Sync Operations', () {
    late String houseId;

    setUp(() async {
      houseId = 'sync-house-luggages';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Sync House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    test(
      'markLuggageAsSynced overwrites updatedAt with server timestamp '
      '(post fix #6: server-side updated_at)',
      () async {
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'l-server-ts',
            houseId: houseId,
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime(2026, 5, 1, 7, 0),
            updatedAt: DateTime(2026, 5, 1, 8, 0),
            syncStatus: const Value(SyncStatus.pendingUpdate),
          ),
        );

        final serverTs = DateTime(2026, 5, 1, 12, 0);
        await database.luggagesDao.markLuggageAsSynced(
          'l-server-ts',
          serverTs,
        );

        final luggage =
            await database.luggagesDao.getLuggageById('l-server-ts');
        expect(
          luggage!.updatedAt,
          equals(serverTs),
          reason:
              'updatedAt deve essere allineato al server timestamp per '
              'rendere immune la LWW al clock drift del client',
        );
        expect(luggage.syncStatus, equals(SyncStatus.synced));
        expect(luggage.lastSyncedAt, equals(serverTs));
      },
    );

    test('resetSyncRetries clears retry counter, error and backoff', () async {
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: 'l-blocked',
          houseId: houseId,
          name: 'Zaino',
          sizeType: LuggageSize.cabinBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await database.luggagesDao.incrementSyncRetry('l-blocked', 'boom');
      }

      final reset = await database.luggagesDao.resetSyncRetries();
      expect(reset, greaterThan(0));

      final luggage = await database.luggagesDao.getLuggageById('l-blocked');
      expect(luggage!.syncRetryCount, equals(0));
      expect(luggage.lastSyncError, isNull);
      expect(luggage.nextSyncAttemptAt, isNull);
    });

    test('wipeAll physically removes every luggage row', () async {
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: 'l-wipe-1',
          houseId: houseId,
          name: 'A',
          sizeType: LuggageSize.cabinBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: 'l-wipe-2',
          houseId: houseId,
          name: 'B',
          sizeType: LuggageSize.holdBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.luggagesDao.wipeAll();

      final allRows = await database.select(database.luggages).get();
      expect(allRows, isEmpty);
    });

    test('updateLuggage preserves sync metadata when companion omits sync fields', () async {
      final originalSyncedAt = DateTime(2026, 5, 1, 8, 0);
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: 'l-keep-sync',
          houseId: houseId,
          name: 'Original',
          sizeType: LuggageSize.cabinBaggage,
          createdAt: DateTime(2026, 5, 1, 7, 0),
          updatedAt: DateTime(2026, 5, 1, 7, 0),
          syncStatus: const Value(SyncStatus.synced),
          syncRetryCount: const Value(3),
          lastSyncedAt: Value(originalSyncedAt),
        ),
      );

      await database.luggagesDao.updateLuggage(
        LuggagesCompanion(
          id: const Value('l-keep-sync'),
          houseId: Value(houseId),
          name: const Value('Renamed'),
          sizeType: const Value(LuggageSize.cabinBaggage),
          createdAt: Value(DateTime(2026, 5, 1, 7, 0)),
          updatedAt: Value(DateTime(2026, 5, 1, 10, 0)),
        ),
      );

      final luggage = await database.luggagesDao.getLuggageById('l-keep-sync');
      expect(luggage!.name, equals('Renamed'));
      expect(luggage.lastSyncedAt, equals(originalSyncedAt));
      expect(luggage.syncRetryCount, equals(3));
      expect(luggage.syncStatus, equals(SyncStatus.pendingUpdate));
    });
  });
}
