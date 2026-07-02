import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for HousesDao.
///
/// Tests the DAO operations for houses including:
/// - CRUD operations on houses
/// - Soft-delete con cascade manuale su items, spaces e luggages
/// - Comportamento del filtro isDeleted nei metodi di lettura
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('HousesDao - Soft Delete Cascade', () {
    test(
      'should soft-delete house and cascade soft-delete all items atomically',
      () async {
        // === ARRANGE ===
        final houseId = 'test-house-fk-items';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'House with Items',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final item1Id = 'item-fk-1';
        final item2Id = 'item-fk-2';

        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: item1Id,
            houseId: houseId,
            name: 'Item 1',
            category: ItemCategory.elettronica,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: item2Id,
            houseId: houseId,
            name: 'Item 2',
            category: ItemCategory.vestiti,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Verify initial state
        expect(await database.housesDao.getHouseById(houseId), isA<House>());
        expect(
          await database.itemsDao.getItemsByHouseId(houseId),
          hasLength(2),
        );

        // === ACT ===
        // Soft-delete: deve riuscire anche con items collegati
        final result = await database.housesDao.deleteHouse(houseId);

        // === ASSERT ===
        expect(result, equals(1));

        // House è invisibile alle query di lettura (isDeleted = true)
        expect(await database.housesDao.getHouseById(houseId), equals(null));

        // Items sono invisibili per cascade soft-delete
        expect(await database.itemsDao.getItemsByHouseId(houseId), isEmpty);
        expect(await database.itemsDao.getItemById(item1Id), equals(null));
        expect(await database.itemsDao.getItemById(item2Id), equals(null));
      },
    );

    test('should soft-delete a house with no dependents', () async {
      // === ARRANGE ===
      final houseId = 'test-house-no-items';

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Empty House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(await database.housesDao.getHouseById(houseId), isA<House>());

      // === ACT ===
      final deleteResult = await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      expect(deleteResult, equals(1));
      expect(await database.housesDao.getHouseById(houseId), equals(null));
    });

    test(
      'should soft-delete a house after manually soft-deleting its item',
      () async {
        // === ARRANGE ===
        final houseId = 'test-house-manual-cleanup';

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'House with Manual Cleanup',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final itemId = 'item-manual-cleanup';
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: itemId,
            houseId: houseId,
            name: 'Item to Delete',
            category: ItemCategory.varie,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        expect(await database.itemsDao.getItemById(itemId), isA<Item>());

        // === ACT ===
        await database.itemsDao.deleteItem(itemId);
        final deleteResult = await database.housesDao.deleteHouse(houseId);

        // === ASSERT ===
        expect(deleteResult, equals(1));
        expect(await database.housesDao.getHouseById(houseId), equals(null));
        expect(await database.itemsDao.getItemById(itemId), equals(null));
      },
    );

    test('should cascade delete spaces when a house is deleted', () async {
      // === ARRANGE ===
      final houseId = 'test-house-spaces-cascade';

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House with Spaces',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Create spaces linked to the house
      final space1Id = 'space-cascade-1';
      final space2Id = 'space-cascade-2';

      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: space1Id,
          houseId: houseId,
          name: 'Kitchen',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: space2Id,
          houseId: houseId,
          name: 'Bedroom',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Verify spaces exist
      final spacesBeforeDelete = await database.spacesDao.getSpacesByHouse(
        houseId,
      );
      expect(spacesBeforeDelete, hasLength(2));

      // === ACT ===
      // Soft-delete house: cascade soft-delete agli spazi
      await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      // Verify spaces are cascade deleted
      final spacesAfterDelete = await database.spacesDao.getSpacesByHouse(
        houseId,
      );
      expect(spacesAfterDelete, isEmpty);

      final space1AfterDelete = await database.spacesDao.getSpaceById(space1Id);
      expect(space1AfterDelete, equals(null));

      final space2AfterDelete = await database.spacesDao.getSpaceById(space2Id);
      expect(space2AfterDelete, equals(null));
    });

    test('should cascade delete luggages when a house is deleted', () async {
      // === ARRANGE ===
      final houseId = 'test-house-luggage-cascade';

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House with Luggages',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Create luggages linked to the house
      final luggage1Id = 'luggage-cascade-1';
      final luggage2Id = 'luggage-cascade-2';

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage1Id,
          houseId: houseId,
          name: 'Suitcase',
          sizeType: LuggageSize.holdBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage2Id,
          houseId: houseId,
          name: 'Backpack',
          sizeType: LuggageSize.smallBackpack,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Verify luggages exist
      final luggagesBeforeDelete = await database.luggagesDao
          .getLuggagesByHouse(houseId);
      expect(luggagesBeforeDelete, hasLength(2));

      // === ACT ===
      // Soft-delete house: cascade soft-delete ai bagagli
      await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      // Verify luggages are cascade deleted
      final luggagesAfterDelete = await database.luggagesDao.getLuggagesByHouse(
        houseId,
      );
      expect(luggagesAfterDelete, isEmpty);
    });

    test(
      'should soft-delete house and cascade to items, spaces, and luggages atomically',
      () async {
        // === ARRANGE ===
        // Scenario completo: casa con items (in spazio e in pool), spazi e bagagli.
        // Verifica che il soft-delete cascada a tutti i dipendenti in un'unica operazione.
        final houseId = 'test-house-complex-fk';

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'House with Everything',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final spaceId = 'space-complex';
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: spaceId,
            houseId: houseId,
            name: 'Living Room',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final itemInSpaceId = 'item-in-space';
        final itemNoSpaceId = 'item-no-space';

        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: itemInSpaceId,
            houseId: houseId,
            spaceId: Value(spaceId),
            name: 'Item in Space',
            category: ItemCategory.varie,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: itemNoSpaceId,
            houseId: houseId,
            name: 'Item without Space',
            category: ItemCategory.varie,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'luggage-complex',
            houseId: houseId,
            name: 'Travel Bag',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Verify initial state
        expect(
          await database.itemsDao.getItemsByHouseId(houseId),
          hasLength(2),
        );
        expect(
          await database.spacesDao.getSpacesByHouse(houseId),
          hasLength(1),
        );
        expect(
          await database.luggagesDao.getLuggagesByHouse(houseId),
          hasLength(1),
        );

        // === ACT ===
        // Soft-delete: deve riuscire in un'unica chiamata, anche con dipendenti
        final deleteResult = await database.housesDao.deleteHouse(houseId);

        // === ASSERT ===
        expect(deleteResult, equals(1));

        // Casa, items, spazi e bagagli invisibili nelle query di lettura
        expect(await database.housesDao.getHouseById(houseId), equals(null));
        expect(await database.itemsDao.getItemsByHouseId(houseId), isEmpty);
        expect(await database.spacesDao.getSpacesByHouse(houseId), isEmpty);
        expect(await database.luggagesDao.getLuggagesByHouse(houseId), isEmpty);
      },
    );

    test(
      'should mark cascaded spaces and luggages as pendingUpdate for sync',
      () async {
        // ARRANGE: house with 1 space and 1 luggage, all synced.
        const houseId = 'h-cascade-sync';
        final now = DateTime.now();

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'House',
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: 's-cascade',
            houseId: houseId,
            name: 'Armadio',
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'l-cascade',
            houseId: houseId,
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );

        // ACT
        await database.housesDao.deleteHouse(houseId);

        // ASSERT: read the rows directly bypassing isDeleted filter.
        final spaceRow = await (database.select(
          database.spaces,
        )..where((s) => s.id.equals('s-cascade'))).getSingle();
        expect(
          spaceRow.syncStatus,
          equals(SyncStatus.pendingUpdate),
          reason:
              'cascade must mark the space pending so the tombstone propagates',
        );

        final luggageRow = await (database.select(
          database.luggages,
        )..where((l) => l.id.equals('l-cascade'))).getSingle();
        expect(
          luggageRow.syncStatus,
          equals(SyncStatus.pendingUpdate),
          reason:
              'cascade must mark the luggage pending so the tombstone propagates',
        );
      },
    );
  });

  group('HousesDao - CRUD Operations', () {
    test('should insert and retrieve a house', () async {
      // === ARRANGE ===
      final houseId = 'house-crud-1';
      final houseCompanion = HousesCompanion.insert(
        id: houseId,
        name: 'My Home',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      await database.housesDao.insertHouse(houseCompanion);
      final retrieved = await database.housesDao.getHouseById(houseId);

      // === ASSERT ===
      expect(retrieved, isA<House>());
      expect(retrieved!.id, equals(houseId));
      expect(retrieved.name, equals('My Home'));
    });

    test('should update an existing house', () async {
      // === ARRANGE ===
      final houseId = 'house-update-1';

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Original Name',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // === ACT ===
      final updatedHouse = HousesCompanion(
        id: Value(houseId),
        name: Value('Updated Name'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      final updateResult = await database.housesDao.updateHouse(updatedHouse);
      final retrieved = await database.housesDao.getHouseById(houseId);

      // === ASSERT ===
      expect(updateResult, isTrue);
      expect(retrieved!.name, equals('Updated Name'));
    });

    test('should retrieve all houses', () async {
      // === ARRANGE ===
      final now = DateTime.now();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'house-all-1',
          name: 'House 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'house-all-2',
          name: 'House 2',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'house-all-3',
          name: 'House 3',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // === ACT ===
      final allHouses = await database.housesDao.getAllHouses();

      // === ASSERT ===
      expect(allHouses, hasLength(3));

      final houseNames = allHouses.map((h) => h.name).toList();
      expect(houseNames, containsAll(['House 1', 'House 2', 'House 3']));
    });
  });

  group('HousesDao - Sync Operations', () {
    Future<void> insertHouse(
      String id, {
      SyncStatus status = SyncStatus.pendingCreate,
    }) async {
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: id,
          name: 'House $id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (status != SyncStatus.pendingCreate) {
        await (database.update(database.houses)..where((h) => h.id.equals(id)))
            .write(HousesCompanion(syncStatus: Value(status)));
      }
    }

    test(
      'getPendingSyncHouses returns only non-synced houses below retry limit',
      () async {
        await insertHouse('pending-1');
        await insertHouse('pending-2', status: SyncStatus.pendingUpdate);
        await insertHouse('synced-1', status: SyncStatus.synced);

        final pending = await database.housesDao.getPendingSyncHouses();

        expect(pending, hasLength(2));
        final ids = pending.map((h) => h.id).toSet();
        expect(ids, containsAll(['pending-1', 'pending-2']));
        expect(ids, isNot(contains('synced-1')));
      },
    );

    test('getPendingSyncHouses excludes houses exceeding maxRetries', () async {
      await insertHouse('retry-exhausted');
      await (database.update(database.houses)
            ..where((h) => h.id.equals('retry-exhausted')))
          .write(const HousesCompanion(syncRetryCount: Value(5)));

      final pending = await database.housesDao.getPendingSyncHouses(
        maxRetries: 5,
      );
      expect(pending, isEmpty);
    });

    test(
      'getPendingSyncHouses includes soft-deleted houses (to propagate deletion to server)',
      () async {
        await insertHouse('deleted-pending');
        await database.housesDao.deleteHouse('deleted-pending');

        final pending = await database.housesDao.getPendingSyncHouses();
        expect(pending, hasLength(1));
        expect(pending.first.id, equals('deleted-pending'));
        expect(pending.first.isDeleted, isTrue);
      },
    );

    test(
      'markHouseAsSynced resets retry state and sets lastSyncedAt',
      () async {
        await insertHouse('to-sync');
        await database.housesDao.incrementSyncRetry('to-sync', 'timeout');

        final serverTime = DateTime(2026, 4, 28, 12, 0);
        await database.housesDao.markHouseAsSynced('to-sync', serverTime);

        final house = await database.housesDao.getHouseById('to-sync');
        expect(house, isA<House>());
        expect(house!.syncStatus, equals(SyncStatus.synced));
        expect(house.syncRetryCount, equals(0));
        expect(house.lastSyncError, equals(null));
        expect(house.lastSyncedAt, equals(serverTime));
      },
    );

    test('incrementSyncRetry increments count and records error', () async {
      await insertHouse('retry-me');

      await database.housesDao.incrementSyncRetry(
        'retry-me',
        'network timeout',
      );
      var house = await database.housesDao.getHouseById('retry-me');
      expect(house!.syncRetryCount, equals(1));
      expect(house.lastSyncError, equals('network timeout'));

      await database.housesDao.incrementSyncRetry('retry-me', 'server 500');
      house = await database.housesDao.getHouseById('retry-me');
      expect(house!.syncRetryCount, equals(2));
      expect(house.lastSyncError, equals('server 500'));
    });

    test('incrementSyncRetry is a no-op for non-existent house', () async {
      await database.housesDao.incrementSyncRetry('ghost-id', 'error');
    });

    test('new houses default to pendingCreate sync status', () async {
      await insertHouse('fresh');
      final house = await database.housesDao.getHouseById('fresh');
      expect(house!.syncStatus, equals(SyncStatus.pendingCreate));
      expect(house.syncRetryCount, equals(0));
      expect(house.lastSyncError, equals(null));
      expect(house.userId, equals(null));
    });

    test('markHouseAsSynced overwrites updatedAt with server timestamp '
        '(post fix #6: server-side updated_at via Postgres trigger)', () async {
      final clientUpdatedAt = DateTime(2026, 5, 1, 8, 0);
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-server-ts',
          name: 'House',
          createdAt: DateTime(2026, 5, 1, 7, 0),
          updatedAt: clientUpdatedAt,
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      // Il server (trigger Postgres `set_updated_at_to_now`) ignora il
      // valore inviato dal client e ritorna NOW() come updated_at
      // ufficiale. markHouseAsSynced lo applica al record locale per
      // mantenere allineato il pivot LWW.
      final serverTs = DateTime(2026, 5, 1, 12, 0);
      await database.housesDao.markHouseAsSynced('h-server-ts', serverTs);

      final house = await database.housesDao.getHouseById('h-server-ts');
      expect(
        house!.updatedAt,
        equals(serverTs),
        reason:
            'updatedAt deve essere allineato al server timestamp per '
            'rendere immune la LWW al clock drift del client',
      );
      expect(house.syncStatus, equals(SyncStatus.synced));
      expect(house.lastSyncedAt, equals(serverTs));
    });

    test('resetSyncRetries clears retry counter, error and backoff', () async {
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-blocked',
          name: 'House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      // Simulate 5 failed sync attempts: record blocked from further retries.
      for (var i = 0; i < 5; i++) {
        await database.housesDao.incrementSyncRetry('h-blocked', 'boom');
      }
      var house = await database.housesDao.getHouseById('h-blocked');
      expect(house!.syncRetryCount, equals(5));
      expect(house.lastSyncError, equals('boom'));
      expect(house.nextSyncAttemptAt, isNotNull);

      final reset = await database.housesDao.resetSyncRetries();

      expect(
        reset,
        greaterThan(0),
        reason: 'should return the number of records reset',
      );
      house = await database.housesDao.getHouseById('h-blocked');
      expect(house!.syncRetryCount, equals(0));
      expect(house.lastSyncError, isNull);
      expect(house.nextSyncAttemptAt, isNull);
    });

    test('wipeAll physically removes every house row', () async {
      await insertHouse('h-1');
      await insertHouse('h-2');
      await insertHouse('h-3', status: SyncStatus.synced);

      await database.housesDao.wipeAll();

      // Bypass isDeleted filter: nothing should remain at all.
      final allRows = await database.select(database.houses).get();
      expect(
        allRows,
        isEmpty,
        reason: 'wipeAll must do a physical delete, not soft-delete',
      );
    });

    test(
      'updateHouse preserves sync metadata when companion omits sync fields',
      () async {
        final originalSyncedAt = DateTime(2026, 5, 1, 8, 0);
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-keep-sync',
            name: 'Original',
            createdAt: DateTime(2026, 5, 1, 7, 0),
            updatedAt: DateTime(2026, 5, 1, 7, 0),
            syncStatus: const Value(SyncStatus.synced),
            syncRetryCount: const Value(3),
            lastSyncedAt: Value(originalSyncedAt),
          ),
        );

        // Caller (repository) updates only the model fields, omitting sync
        // metadata — the DAO must preserve them and mark the record pending.
        await database.housesDao.updateHouse(
          HousesCompanion(
            id: const Value('h-keep-sync'),
            name: const Value('Renamed'),
            createdAt: Value(DateTime(2026, 5, 1, 7, 0)),
            updatedAt: Value(DateTime(2026, 5, 1, 10, 0)),
          ),
        );

        final house = await database.housesDao.getHouseById('h-keep-sync');
        expect(house!.name, equals('Renamed'));
        expect(
          house.lastSyncedAt,
          equals(originalSyncedAt),
          reason: 'updateHouse must not reset lastSyncedAt',
        );
        expect(
          house.syncRetryCount,
          equals(3),
          reason: 'updateHouse must not reset syncRetryCount',
        );
        expect(
          house.syncStatus,
          equals(SyncStatus.pendingUpdate),
          reason: 'updateHouse must mark the record pending so it gets pushed',
        );
      },
    );
  });

  group('HousesDao - incrementSyncRetry', () {
    test('non modifica updatedAt (pivot LWW)', () async {
      final t0 = DateTime(2026, 5, 1, 8, 0);
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-retry',
          name: 'Casa',
          createdAt: t0,
          updatedAt: t0,
        ),
      );

      await database.housesDao.incrementSyncRetry('h-retry', 'boom');

      final house = await database.housesDao.findHouseById('h-retry');
      expect(house!.updatedAt, equals(t0),
          reason: 'il retry bookkeeping non deve toccare il pivot LWW');
      expect(house.syncRetryCount, equals(1));
      expect(house.lastSyncError, equals('boom'));
      expect(house.nextSyncAttemptAt, isNotNull);
    });
  });

  group('HousesDao - setPrimaryHouse', () {
    Future<void> insertHouseWithStatus(
      AppDatabase db, {
      required String id,
      required String name,
      bool isPrimary = false,
      SyncStatus syncStatus = SyncStatus.synced,
    }) async {
      await db.housesDao.insertHouse(
        HousesCompanion.insert(
          id: id,
          name: name,
          isPrimary: Value(isPrimary),
          syncStatus: Value(syncStatus),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    test('sets target as primary and clears others', () async {
      await insertHouseWithStatus(
        database,
        id: 'h1',
        name: 'H1',
        isPrimary: true,
      );
      await insertHouseWithStatus(database, id: 'h2', name: 'H2');
      await insertHouseWithStatus(database, id: 'h3', name: 'H3');

      await database.housesDao.setPrimaryHouse('h2');

      final byId = {
        for (final h in await database.housesDao.getAllHouses()) h.id: h,
      };
      expect(byId['h1']!.isPrimary, isFalse);
      expect(byId['h2']!.isPrimary, isTrue);
      expect(byId['h3']!.isPrimary, isFalse);
    });

    test('idempotent when target is already primary', () async {
      await insertHouseWithStatus(
        database,
        id: 'h1',
        name: 'H1',
        isPrimary: true,
      );
      await insertHouseWithStatus(database, id: 'h2', name: 'H2');

      await database.housesDao.setPrimaryHouse('h1');

      final byId = {
        for (final h in await database.housesDao.getAllHouses()) h.id: h,
      };
      expect(byId['h1']!.isPrimary, isTrue);
      expect(byId['h2']!.isPrimary, isFalse);
    });

    test('does not touch soft-deleted houses', () async {
      await insertHouseWithStatus(
        database,
        id: 'h1',
        name: 'H1',
        isPrimary: true,
      );
      await insertHouseWithStatus(database, id: 'h2', name: 'H2');
      await (database.update(database.houses)..where((h) => h.id.equals('h1')))
          .write(const HousesCompanion(isDeleted: Value(true)));

      await database.housesDao.setPrimaryHouse('h2');

      final all = await database.select(database.houses).get();
      final byId = {for (final h in all) h.id: h};
      expect(byId['h1']!.isPrimary, isTrue); // untouched — isDeleted
      expect(byId['h2']!.isPrimary, isTrue);
    });

    test('marks synced rows as pendingUpdate', () async {
      await insertHouseWithStatus(
        database,
        id: 'h1',
        name: 'H1',
        isPrimary: true,
        syncStatus: SyncStatus.synced,
      );
      await insertHouseWithStatus(
        database,
        id: 'h2',
        name: 'H2',
        syncStatus: SyncStatus.synced,
      );

      await database.housesDao.setPrimaryHouse('h2');

      final all = await database.select(database.houses).get();
      final byId = {for (final h in all) h.id: h};
      expect(byId['h1']!.syncStatus, equals(SyncStatus.pendingUpdate));
      expect(byId['h2']!.syncStatus, equals(SyncStatus.pendingUpdate));
    });

    test(
      'preserves pendingCreate — does not degrade to pendingUpdate',
      () async {
        // Scenario: casa creata offline (pendingCreate) e subito impostata come
        // principale. Se sovrascrivessimo con pendingUpdate, il sync manderebbe
        // un PATCH per un record inesistente sul server → sync failure.
        await insertHouseWithStatus(
          database,
          id: 'h1',
          name: 'H1 (synced)',
          isPrimary: true,
          syncStatus: SyncStatus.synced,
        );
        await insertHouseWithStatus(
          database,
          id: 'h2',
          name: 'H2 (offline)',
          isPrimary: false,
          syncStatus: SyncStatus.pendingCreate,
        );

        await database.housesDao.setPrimaryHouse('h2');

        final all = await database.select(database.houses).get();
        final byId = {for (final h in all) h.id: h};
        // h1 era synced → ora pendingUpdate (verrà aggiornato sul server)
        expect(byId['h1']!.syncStatus, equals(SyncStatus.pendingUpdate));
        // h2 era pendingCreate → deve rimanere pendingCreate
        // (verrà inserito sul server con isPrimary=true)
        expect(byId['h2']!.syncStatus, equals(SyncStatus.pendingCreate));
        expect(byId['h2']!.isPrimary, isTrue);
      },
    );
  });
}
