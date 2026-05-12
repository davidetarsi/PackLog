import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
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
    test('should soft-delete house and cascade soft-delete all items atomically', () async {
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
      expect(await database.itemsDao.getItemsByHouseId(houseId), hasLength(2));

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
    });

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

    test('should soft-delete a house after manually soft-deleting its item', () async {
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
    });

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
      final spacesBeforeDelete = await database.spacesDao.getSpacesByHouse(houseId);
      expect(spacesBeforeDelete, hasLength(2));

      // === ACT ===
      // Soft-delete house: cascade soft-delete agli spazi
      await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      // Verify spaces are cascade deleted
      final spacesAfterDelete = await database.spacesDao.getSpacesByHouse(houseId);
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
      final luggagesBeforeDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesBeforeDelete, hasLength(2));

      // === ACT ===
      // Soft-delete house: cascade soft-delete ai bagagli
      await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      // Verify luggages are cascade deleted
      final luggagesAfterDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesAfterDelete, isEmpty);
    });

    test('should soft-delete house and cascade to items, spaces, and luggages atomically', () async {
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
      expect(await database.itemsDao.getItemsByHouseId(houseId), hasLength(2));
      expect(await database.spacesDao.getSpacesByHouse(houseId), hasLength(1));
      expect(await database.luggagesDao.getLuggagesByHouse(houseId), hasLength(1));

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
    });
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
    Future<void> insertHouse(String id, {SyncStatus status = SyncStatus.pendingCreate}) async {
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: id,
          name: 'House $id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (status != SyncStatus.pendingCreate) {
        await (database.update(database.houses)
              ..where((h) => h.id.equals(id)))
            .write(HousesCompanion(syncStatus: Value(status)));
      }
    }

    test('getPendingSyncHouses returns only non-synced houses below retry limit', () async {
      await insertHouse('pending-1');
      await insertHouse('pending-2', status: SyncStatus.pendingUpdate);
      await insertHouse('synced-1', status: SyncStatus.synced);

      final pending = await database.housesDao.getPendingSyncHouses();

      expect(pending, hasLength(2));
      final ids = pending.map((h) => h.id).toSet();
      expect(ids, containsAll(['pending-1', 'pending-2']));
      expect(ids, isNot(contains('synced-1')));
    });

    test('getPendingSyncHouses excludes houses exceeding maxRetries', () async {
      await insertHouse('retry-exhausted');
      await (database.update(database.houses)
            ..where((h) => h.id.equals('retry-exhausted')))
          .write(const HousesCompanion(syncRetryCount: Value(5)));

      final pending = await database.housesDao.getPendingSyncHouses(maxRetries: 5);
      expect(pending, isEmpty);
    });

    test('getPendingSyncHouses includes soft-deleted houses (to propagate deletion to server)', () async {
      await insertHouse('deleted-pending');
      await database.housesDao.deleteHouse('deleted-pending');

      final pending = await database.housesDao.getPendingSyncHouses();
      expect(pending, hasLength(1));
      expect(pending.first.id, equals('deleted-pending'));
      expect(pending.first.isDeleted, isTrue);
    });

    test('markHouseAsSynced resets retry state and sets lastSyncedAt', () async {
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
    });

    test('incrementSyncRetry increments count and records error', () async {
      await insertHouse('retry-me');

      await database.housesDao.incrementSyncRetry('retry-me', 'network timeout');
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
  });
}
