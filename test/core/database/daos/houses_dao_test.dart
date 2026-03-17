import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:stuff_tracker_2/core/database/database.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for HousesDao.
/// 
/// Tests the DAO operations for houses including:
/// - CRUD operations on houses
/// - SQLite CASCADE DELETE referential integrity (items, spaces, luggages)
/// - Foreign key constraints
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('HousesDao - SQLite Foreign Key Constraints', () {
    test('should prevent deleting a house with items (FK constraint enforced)', () async {
      // === ARRANGE ===
      // Step 1: Insert a house
      final houseId = 'test-house-fk-items';
      final houseCompanion = HousesCompanion.insert(
        id: houseId,
        name: 'House with Items',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await database.housesDao.insertHouse(houseCompanion);
      
      // Step 2: Insert items linked to the house
      final item1Id = 'item-fk-1';
      final item2Id = 'item-fk-2';
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: item1Id,
          houseId: houseId,
          name: 'Item 1',
          category: 'elettronica',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: item2Id,
          houseId: houseId,
          name: 'Item 2',
          category: 'vestiti',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Verify initial state: house and items exist
      final houseBeforeDelete = await database.housesDao.getHouseById(houseId);
      expect(houseBeforeDelete, isA<House>());
      
      final itemsBeforeDelete = await database.itemsDao.getItemsByHouseId(houseId);
      expect(itemsBeforeDelete, hasLength(2));

      // === ACT & ASSERT ===
      // Attempt to delete the house - SQLite FK constraint should PREVENT deletion
      // because items exist and the Items.houseId FK does NOT have CASCADE DELETE
      expect(
        () async => await database.housesDao.deleteHouse(houseId),
        throwsA(isA<Exception>()),
      );
      
      // Verify house still exists (delete was prevented)
      final houseAfterFailedDelete = await database.housesDao.getHouseById(houseId);
      expect(houseAfterFailedDelete, isA<House>());
      expect(houseAfterFailedDelete!.id, equals(houseId));
      
      // Verify items still exist (unchanged)
      final itemsAfterFailedDelete = await database.itemsDao.getItemsByHouseId(houseId);
      expect(itemsAfterFailedDelete, hasLength(2));
      
      final item1AfterFailedDelete = await database.itemsDao.getItemById(item1Id);
      expect(item1AfterFailedDelete, isA<Item>());
      
      final item2AfterFailedDelete = await database.itemsDao.getItemById(item2Id);
      expect(item2AfterFailedDelete, isA<Item>());
    });

    test('should allow deleting a house with no items', () async {
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
      
      // Verify house exists
      final houseBeforeDelete = await database.housesDao.getHouseById(houseId);
      expect(houseBeforeDelete, isA<House>());

      // === ACT ===
      // Delete the house - should succeed because no items exist
      final deleteResult = await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      expect(deleteResult, equals(1));
      
      // Verify house is deleted
      final houseAfterDelete = await database.housesDao.getHouseById(houseId);
      expect(houseAfterDelete, equals(null));
    });

    test('should allow deleting a house after manually deleting all its items', () async {
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
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Verify item exists
      final itemBeforeDelete = await database.itemsDao.getItemById(itemId);
      expect(itemBeforeDelete, isA<Item>());

      // === ACT ===
      // Manually delete all items first
      await database.itemsDao.deleteItem(itemId);
      
      // Now delete the house - should succeed
      final deleteResult = await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      expect(deleteResult, equals(1));
      
      // Verify house is deleted
      final houseAfterDelete = await database.housesDao.getHouseById(houseId);
      expect(houseAfterDelete, equals(null));
      
      // Verify item was already deleted in previous step
      final itemAfterDelete = await database.itemsDao.getItemById(itemId);
      expect(itemAfterDelete, equals(null));
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
      // Delete house WITHOUT items (spaces CASCADE delete, items prevent deletion)
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
          sizeType: 'hold_baggage',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage2Id,
          houseId: houseId,
          name: 'Backpack',
          sizeType: 'small_backpack',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Verify luggages exist
      final luggagesBeforeDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesBeforeDelete, hasLength(2));

      // === ACT ===
      // Delete house WITHOUT items (luggages CASCADE delete, items prevent deletion)
      await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      // Verify luggages are cascade deleted
      final luggagesAfterDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesAfterDelete, isEmpty);
    });

    test('should prevent deletion when house has items, but cascade delete spaces and luggages after items are removed', () async {
      // === ARRANGE ===
      // Test that demonstrates the referential integrity order:
      // 1. Items prevent house deletion (no CASCADE)
      // 2. Spaces and Luggages CASCADE delete when house is deleted
      final houseId = 'test-house-complex-fk';
      
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House with Everything',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Create space
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
      
      // Create items (some in space, some not)
      final itemInSpaceId = 'item-in-space';
      final itemNoSpaceId = 'item-no-space';
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: itemInSpaceId,
          houseId: houseId,
          spaceId: Value(spaceId),
          name: 'Item in Space',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: itemNoSpaceId,
          houseId: houseId,
          name: 'Item without Space',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Create luggage
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: 'luggage-complex',
          houseId: houseId,
          name: 'Travel Bag',
          sizeType: 'cabin_baggage',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Verify all entities exist
      final itemsBeforeDelete = await database.itemsDao.getItemsByHouseId(houseId);
      expect(itemsBeforeDelete, hasLength(2));
      
      final spacesBeforeDelete = await database.spacesDao.getSpacesByHouse(houseId);
      expect(spacesBeforeDelete, hasLength(1));
      
      final luggagesBeforeDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesBeforeDelete, hasLength(1));

      // === ACT & ASSERT (Part 1) ===
      // Attempt to delete house - should FAIL because items exist
      expect(
        () async => await database.housesDao.deleteHouse(houseId),
        throwsA(isA<Exception>()),
      );
      
      // Verify all entities still exist after failed deletion
      final houseAfterFailedDelete = await database.housesDao.getHouseById(houseId);
      expect(houseAfterFailedDelete, isA<House>());
      
      final itemsAfterFailedDelete = await database.itemsDao.getItemsByHouseId(houseId);
      expect(itemsAfterFailedDelete, hasLength(2));
      
      final spacesAfterFailedDelete = await database.spacesDao.getSpacesByHouse(houseId);
      expect(spacesAfterFailedDelete, hasLength(1));
      
      final luggagesAfterFailedDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesAfterFailedDelete, hasLength(1));

      // === ACT (Part 2) ===
      // Manually delete all items first
      await database.itemsDao.deleteItem(itemInSpaceId);
      await database.itemsDao.deleteItem(itemNoSpaceId);
      
      // Now delete the house - should succeed and CASCADE delete spaces/luggages
      final deleteResult = await database.housesDao.deleteHouse(houseId);

      // === ASSERT (Part 2) ===
      expect(deleteResult, equals(1));
      
      // Verify house is deleted
      final houseAfterDelete = await database.housesDao.getHouseById(houseId);
      expect(houseAfterDelete, equals(null));
      
      // Verify items were manually deleted earlier
      final itemsAfterDelete = await database.itemsDao.getItemsByHouseId(houseId);
      expect(itemsAfterDelete, isEmpty);
      
      // Verify spaces and luggages are CASCADE deleted automatically by SQLite
      final spacesAfterDelete = await database.spacesDao.getSpacesByHouse(houseId);
      expect(spacesAfterDelete, isEmpty);
      
      final luggagesAfterDelete = await database.luggagesDao.getLuggagesByHouse(houseId);
      expect(luggagesAfterDelete, isEmpty);
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
}
