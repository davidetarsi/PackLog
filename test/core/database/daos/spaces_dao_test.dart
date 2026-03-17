import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:stuff_tracker_2/core/database/database.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for SpacesDao.
/// 
/// Tests the DAO operations for spaces including:
/// - CRUD operations on spaces
/// - SQLite SET NULL referential integrity (items remain but spaceId becomes null)
/// - Foreign key constraints
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('SpacesDao - SQLite SET NULL Constraint', () {
    test('should set spaceId to NULL on items when a space is deleted, keeping the item in the general pool', () async {
      // === ARRANGE ===
      // Step 1: Insert a house (required for foreign key)
      final houseId = 'test-house-set-null';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Test House for SET NULL',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Step 2: Insert a space linked to the house
      final spaceId = 'test-space-set-null';
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: spaceId,
          houseId: houseId,
          name: 'Kitchen',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Step 3: Insert items - some linked to the space, some not
      final itemInSpaceId = 'item-in-space';
      final itemInSpace2Id = 'item-in-space-2';
      final itemNoSpaceId = 'item-no-space';
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: itemInSpaceId,
          houseId: houseId,
          spaceId: Value(spaceId), // Item IS in the space
          name: 'Plate',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: itemInSpace2Id,
          houseId: houseId,
          spaceId: Value(spaceId), // Item IS in the space
          name: 'Cup',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: itemNoSpaceId,
          houseId: houseId,
          // No spaceId - item is in general pool
          name: 'Random Item',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Verify initial state: space and items exist with correct spaceId
      final spaceBeforeDelete = await database.spacesDao.getSpaceById(spaceId);
      expect(spaceBeforeDelete, isA<Space>());
      
      final itemInSpaceBeforeDelete = await database.itemsDao.getItemById(itemInSpaceId);
      expect(itemInSpaceBeforeDelete, isA<Item>());
      expect(itemInSpaceBeforeDelete!.spaceId, equals(spaceId));
      
      final itemInSpace2BeforeDelete = await database.itemsDao.getItemById(itemInSpace2Id);
      expect(itemInSpace2BeforeDelete, isA<Item>());
      expect(itemInSpace2BeforeDelete!.spaceId, equals(spaceId));
      
      final itemNoSpaceBeforeDelete = await database.itemsDao.getItemById(itemNoSpaceId);
      expect(itemNoSpaceBeforeDelete, isA<Item>());
      expect(itemNoSpaceBeforeDelete!.spaceId, equals(null));

      // === ACT ===
      // Delete the space - SQLite SET NULL should automatically set spaceId to NULL on items
      final deleteResult = await database.spacesDao.deleteSpace(spaceId);

      // === ASSERT ===
      // Verify delete operation affected 1 row
      expect(deleteResult, equals(1));
      
      // Verify space is deleted
      final spaceAfterDelete = await database.spacesDao.getSpaceById(spaceId);
      expect(spaceAfterDelete, equals(null));
      
      // CRITICAL: Verify items still exist but spaceId is now NULL
      // We did NOT explicitly call updateItem() - SQLite SET NULL did this automatically
      final itemInSpaceAfterDelete = await database.itemsDao.getItemById(itemInSpaceId);
      expect(itemInSpaceAfterDelete, isA<Item>());
      expect(itemInSpaceAfterDelete!.name, equals('Plate'));
      expect(itemInSpaceAfterDelete.houseId, equals(houseId)); // House FK unchanged
      expect(itemInSpaceAfterDelete.spaceId, equals(null)); // Space FK set to NULL by SQLite
      
      final itemInSpace2AfterDelete = await database.itemsDao.getItemById(itemInSpace2Id);
      expect(itemInSpace2AfterDelete, isA<Item>());
      expect(itemInSpace2AfterDelete!.name, equals('Cup'));
      expect(itemInSpace2AfterDelete.spaceId, equals(null)); // Space FK set to NULL by SQLite
      
      // Verify item that was already in general pool remains unchanged
      final itemNoSpaceAfterDelete = await database.itemsDao.getItemById(itemNoSpaceId);
      expect(itemNoSpaceAfterDelete, isA<Item>());
      expect(itemNoSpaceAfterDelete!.name, equals('Random Item'));
      expect(itemNoSpaceAfterDelete.spaceId, equals(null)); // Already null, still null
      
      // Verify all items still belong to the house
      final allHouseItems = await database.itemsDao.getItemsByHouseId(houseId);
      expect(allHouseItems, hasLength(3)); // All 3 items still exist
      
      // Verify items with null spaceId are considered in "general pool"
      final generalPoolItems = allHouseItems.where((item) => item.spaceId == null).toList();
      expect(generalPoolItems, hasLength(3)); // All 3 items now have null spaceId
    });

    test('should handle multiple items in the same space when space is deleted', () async {
      // === ARRANGE ===
      final houseId = 'house-multi-items';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Multi Items House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final spaceId = 'bedroom-multi';
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: spaceId,
          houseId: houseId,
          name: 'Bedroom',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Create 5 items in the same space
      final itemIds = <String>[];
      for (int i = 1; i <= 5; i++) {
        final itemId = 'bedroom-item-$i';
        itemIds.add(itemId);
        
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: itemId,
            houseId: houseId,
            spaceId: Value(spaceId),
            name: 'Bedroom Item $i',
            category: 'varie',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      
      // Verify all items are in the space
      for (final itemId in itemIds) {
        final item = await database.itemsDao.getItemById(itemId);
        expect(item!.spaceId, equals(spaceId));
      }

      // === ACT ===
      await database.spacesDao.deleteSpace(spaceId);

      // === ASSERT ===
      // Verify all items still exist with spaceId set to NULL
      for (final itemId in itemIds) {
        final item = await database.itemsDao.getItemById(itemId);
        expect(item, isA<Item>());
        expect(item!.spaceId, equals(null));
        expect(item.houseId, equals(houseId)); // House unchanged
      }
    });

    test('should not affect items in other spaces when one space is deleted', () async {
      // === ARRANGE ===
      final houseId = 'house-multi-spaces';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Multi Spaces House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Create two spaces
      final kitchenSpaceId = 'kitchen-space';
      final bedroomSpaceId = 'bedroom-space';
      
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: kitchenSpaceId,
          houseId: houseId,
          name: 'Kitchen',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: bedroomSpaceId,
          houseId: houseId,
          name: 'Bedroom',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Create items in each space
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'kitchen-item',
          houseId: houseId,
          spaceId: Value(kitchenSpaceId),
          name: 'Kitchen Item',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'bedroom-item',
          houseId: houseId,
          spaceId: Value(bedroomSpaceId),
          name: 'Bedroom Item',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // === ACT ===
      // Delete only the kitchen space
      await database.spacesDao.deleteSpace(kitchenSpaceId);

      // === ASSERT ===
      // Kitchen item should have spaceId set to NULL
      final kitchenItem = await database.itemsDao.getItemById('kitchen-item');
      expect(kitchenItem, isA<Item>());
      expect(kitchenItem!.spaceId, equals(null));
      
      // Bedroom item should still have its spaceId intact
      final bedroomItem = await database.itemsDao.getItemById('bedroom-item');
      expect(bedroomItem, isA<Item>());
      expect(bedroomItem!.spaceId, equals(bedroomSpaceId)); // Unchanged
      
      // Bedroom space should still exist
      final bedroomSpace = await database.spacesDao.getSpaceById(bedroomSpaceId);
      expect(bedroomSpace, isA<Space>());
    });
  });

  group('SpacesDao - CRUD Operations', () {
    test('should insert and retrieve a space', () async {
      // === ARRANGE ===
      final houseId = 'house-space-crud';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'CRUD House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final spaceId = 'space-crud-1';
      final spaceCompanion = SpacesCompanion.insert(
        id: spaceId,
        houseId: houseId,
        name: 'Living Room',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      await database.spacesDao.insertSpace(spaceCompanion);
      final retrieved = await database.spacesDao.getSpaceById(spaceId);

      // === ASSERT ===
      expect(retrieved, isA<Space>());
      expect(retrieved!.id, equals(spaceId));
      expect(retrieved.name, equals('Living Room'));
      expect(retrieved.houseId, equals(houseId));
    });

    test('should update an existing space', () async {
      // === ARRANGE ===
      final houseId = 'house-space-update';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Update House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final spaceId = 'space-update-1';
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: spaceId,
          houseId: houseId,
          name: 'Original Name',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // === ACT ===
      final updatedSpace = SpacesCompanion(
        id: Value(spaceId),
        houseId: Value(houseId),
        name: Value('Updated Name'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      
      final updateResult = await database.spacesDao.updateSpace(updatedSpace);
      final retrieved = await database.spacesDao.getSpaceById(spaceId);

      // === ASSERT ===
      expect(updateResult, isTrue);
      expect(retrieved!.name, equals('Updated Name'));
    });

    test('should retrieve all spaces for a house', () async {
      // === ARRANGE ===
      final houseId = 'house-all-spaces';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'All Spaces House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final now = DateTime.now();
      
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: 'space-1',
          houseId: houseId,
          name: 'Kitchen',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: 'space-2',
          houseId: houseId,
          name: 'Bedroom',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: 'space-3',
          houseId: houseId,
          name: 'Bathroom',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // === ACT ===
      final allSpaces = await database.spacesDao.getSpacesByHouse(houseId);

      // === ASSERT ===
      expect(allSpaces, hasLength(3));
      
      final spaceNames = allSpaces.map((s) => s.name).toList();
      expect(spaceNames, containsAll(['Kitchen', 'Bedroom', 'Bathroom']));
    });
  });

  group('SpacesDao - Foreign Key Constraints', () {
    test('should enforce foreign key constraint when creating space with non-existent house', () async {
      // === ARRANGE ===
      final nonExistentHouseId = 'non-existent-house';
      
      final spaceCompanion = SpacesCompanion.insert(
        id: 'orphan-space',
        houseId: nonExistentHouseId, // This house does NOT exist
        name: 'Orphan Space',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      // Attempt to insert space with invalid foreign key
      // Should fail because PRAGMA foreign_keys = ON
      expect(
        () async => await database.spacesDao.insertSpace(spaceCompanion),
        throwsA(isA<Exception>()),
      );
      
      // Verify space was NOT inserted
      final space = await database.spacesDao.getSpaceById('orphan-space');
      expect(space, equals(null));
    });

    test('should cascade delete space when its parent house is deleted', () async {
      // === ARRANGE ===
      // This test verifies that spaces CASCADE delete when house is deleted
      final houseId = 'house-cascade-space';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Cascade House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final spaceId = 'space-cascade';
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: spaceId,
          houseId: houseId,
          name: 'Test Space',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Verify space exists
      final spaceBeforeDelete = await database.spacesDao.getSpaceById(spaceId);
      expect(spaceBeforeDelete, isA<Space>());

      // === ACT ===
      // Delete the house - space should CASCADE delete
      await database.housesDao.deleteHouse(houseId);

      // === ASSERT ===
      // Space should be cascade deleted
      final spaceAfterDelete = await database.spacesDao.getSpaceById(spaceId);
      expect(spaceAfterDelete, equals(null));
    });
  });
}
