import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/core/database/database.dart';
import 'package:stuff_tracker_2/core/database/services/database_service.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';
import 'package:stuff_tracker_2/features/items/repositories/drift_item_repository.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for DriftItemRepository.
/// 
/// Tests the repository layer to ensure:
/// - Correct bidirectional mapping between ItemModel (domain) and Drift entities
/// - CRUD operations work end-to-end with the database
/// - Foreign key constraints are respected
void main() {
  late AppDatabase database;
  late DatabaseService databaseService;
  late DriftItemRepository repository;

  setUp(() {
    database = createTestDatabase();
    databaseService = DatabaseService(database);
    repository = DriftItemRepository(database.itemsDao, databaseService);
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('DriftItemRepository - Bidirectional Mapping Tests', () {
    test('should correctly map ItemModel -> Companion -> ItemModel (addItem + getItemById)', () async {
      // === ARRANGE ===
      // Step 1: Insert a house (required for FK constraint)
      final houseId = 'test-house-item-mapping';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Test House for Items',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Step 2: Create an ItemModel domain object with specific values
      final now = DateTime.now();
      final originalItem = ItemModel(
        id: 'item-mapping-test',
        houseId: houseId,
        name: 'Gaming Laptop',
        category: ItemCategory.elettronica,
        description: 'MacBook Pro 16"',
        quantity: 1,
        spaceId: null, // Item in general pool
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      // Save using repository (Model -> Companion -> DB)
      await repository.addItem(originalItem);

      // Fetch using repository (DB -> Entity -> Model)
      final fetchedItem = await repository.getItemById(originalItem.id);

      // === ASSERT ===
      // Verify the fetched object is of type ItemModel
      expect(fetchedItem, isA<ItemModel>());

      // Verify ALL fields match exactly (bidirectional mapping integrity)
      expect(fetchedItem.id, equals(originalItem.id));
      expect(fetchedItem.houseId, equals(originalItem.houseId));
      expect(fetchedItem.name, equals(originalItem.name));
      expect(fetchedItem.category, equals(originalItem.category));
      expect(fetchedItem.description, equals(originalItem.description));
      expect(fetchedItem.quantity, equals(originalItem.quantity));
      expect(fetchedItem.spaceId, equals(originalItem.spaceId));
      
      // DateTime comparison (allow small differences due to SQLite precision)
      expect(
        fetchedItem.createdAt.difference(originalItem.createdAt).inSeconds,
        lessThanOrEqualTo(1),
      );
      expect(
        fetchedItem.updatedAt.difference(originalItem.updatedAt).inSeconds,
        lessThanOrEqualTo(1),
      );
    });

    test('should correctly map ItemModel with all category types', () async {
      // === ARRANGE ===
      final houseId = 'test-house-categories';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Test House for Categories',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final itemsToTest = <ItemModel>[
        ItemModel(
          id: 'item-vestiti',
          houseId: houseId,
          name: 'T-Shirt',
          category: ItemCategory.vestiti,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-toiletries',
          houseId: houseId,
          name: 'Toothbrush',
          category: ItemCategory.toiletries,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-elettronica',
          houseId: houseId,
          name: 'Charger',
          category: ItemCategory.elettronica,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-varie',
          houseId: houseId,
          name: 'Keys',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // === ACT ===
      // Save all items
      for (final item in itemsToTest) {
        await repository.addItem(item);
      }

      // Fetch all items back
      final fetchedItems = <ItemModel>[];
      for (final item in itemsToTest) {
        fetchedItems.add(await repository.getItemById(item.id));
      }

      // === ASSERT ===
      // Verify each category is preserved correctly through the mapping
      for (int i = 0; i < itemsToTest.length; i++) {
        expect(
          fetchedItems[i].category,
          equals(itemsToTest[i].category),
          reason: 'Category mapping failed for ${itemsToTest[i].category.name}',
        );
        expect(fetchedItems[i].name, equals(itemsToTest[i].name));
      }
    });

    test('should correctly map ItemModel with spaceId (not null)', () async {
      // === ARRANGE ===
      final houseId = 'test-house-with-space';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House with Spaces',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final spaceId = 'test-kitchen-space';
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: spaceId,
          houseId: houseId,
          name: 'Kitchen',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final itemInSpace = ItemModel(
        id: 'item-in-kitchen',
        houseId: houseId,
        name: 'Plate',
        category: ItemCategory.varie,
        spaceId: spaceId, // Item IS in a specific space
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      await repository.addItem(itemInSpace);
      final fetchedItem = await repository.getItemById(itemInSpace.id);

      // === ASSERT ===
      // Verify spaceId is preserved through mapping
      expect(fetchedItem.spaceId, equals(spaceId));
      expect(fetchedItem.houseId, equals(houseId));
      expect(fetchedItem.name, equals('Plate'));
    });
  });

  group('DriftItemRepository - CRUD Operations via Repository', () {
    test('should add and retrieve multiple items for the same house', () async {
      // === ARRANGE ===
      final houseId = 'test-house-multiple-items';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House with Multiple Items',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final items = [
        ItemModel(
          id: 'item-1',
          houseId: houseId,
          name: 'Item 1',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-2',
          houseId: houseId,
          name: 'Item 2',
          category: ItemCategory.vestiti,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-3',
          houseId: houseId,
          name: 'Item 3',
          category: ItemCategory.elettronica,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // === ACT ===
      for (final item in items) {
        await repository.addItem(item);
      }

      final allItemsForHouse = await repository.getItemsByHouseId(houseId);

      // === ASSERT ===
      expect(allItemsForHouse, hasLength(3));
      
      final names = allItemsForHouse.map((item) => item.name).toList();
      expect(names, containsAll(['Item 1', 'Item 2', 'Item 3']));
    });

    test('should update an existing item and preserve changes', () async {
      // === ARRANGE ===
      final houseId = 'test-house-update';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House for Update Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final originalItem = ItemModel(
        id: 'item-to-update',
        houseId: houseId,
        name: 'Original Name',
        category: ItemCategory.varie,
        quantity: 1,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addItem(originalItem);

      // === ACT ===
      // Update the item (change name, category, and quantity)
      final updatedItem = originalItem.copyWith(
        name: 'Updated Name',
        category: ItemCategory.elettronica,
        quantity: 5,
        updatedAt: DateTime.now(),
      );

      await repository.updateItem(updatedItem);
      final fetchedItem = await repository.getItemById(originalItem.id);

      // === ASSERT ===
      expect(fetchedItem.name, equals('Updated Name'));
      expect(fetchedItem.category, equals(ItemCategory.elettronica));
      expect(fetchedItem.quantity, equals(5));
      expect(fetchedItem.id, equals(originalItem.id)); // ID unchanged
      expect(fetchedItem.houseId, equals(houseId)); // FK unchanged
    });

    test('should delete an item and throw when trying to fetch it', () async {
      // === ARRANGE ===
      final houseId = 'test-house-delete';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House for Delete Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final itemToDelete = ItemModel(
        id: 'item-to-delete',
        houseId: houseId,
        name: 'Item to Delete',
        category: ItemCategory.varie,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addItem(itemToDelete);

      // Verify item exists
      final itemBeforeDelete = await repository.getItemById(itemToDelete.id);
      expect(itemBeforeDelete, isA<ItemModel>());

      // === ACT ===
      final deleteResult = await repository.deleteItem(itemToDelete.id);

      // === ASSERT ===
      expect(deleteResult, isTrue);

      // Attempting to fetch deleted item should throw StateError
      expect(
        () async => await repository.getItemById(itemToDelete.id),
        throwsA(isA<StateError>()),
      );
    });

    test('should retrieve all items across all houses', () async {
      // === ARRANGE ===
      final house1Id = 'house-all-1';
      final house2Id = 'house-all-2';

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: house1Id,
          name: 'House 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: house2Id,
          name: 'House 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final itemsToAdd = [
        ItemModel(
          id: 'item-house1-1',
          houseId: house1Id,
          name: 'House 1 Item 1',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-house1-2',
          houseId: house1Id,
          name: 'House 1 Item 2',
          category: ItemCategory.vestiti,
          createdAt: now,
          updatedAt: now,
        ),
        ItemModel(
          id: 'item-house2-1',
          houseId: house2Id,
          name: 'House 2 Item 1',
          category: ItemCategory.elettronica,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (final item in itemsToAdd) {
        await repository.addItem(item);
      }

      // === ACT ===
      final allItems = await repository.getAllItems();

      // === ASSERT ===
      expect(allItems, hasLength(3));

      // Verify items from both houses are present
      final house1Items = allItems.where((item) => item.houseId == house1Id).toList();
      final house2Items = allItems.where((item) => item.houseId == house2Id).toList();

      expect(house1Items, hasLength(2));
      expect(house2Items, hasLength(1));
    });
  });

  group('DriftItemRepository - Foreign Key Constraints', () {
    test('should fail to add item with non-existent house (FK constraint)', () async {
      // === ARRANGE ===
      final now = DateTime.now();
      final itemWithInvalidHouse = ItemModel(
        id: 'item-invalid-fk',
        houseId: 'non-existent-house-id',
        name: 'Orphan Item',
        category: ItemCategory.varie,
        createdAt: now,
        updatedAt: now,
      );

      // === ACT & ASSERT ===
      // Attempt to add item with invalid FK should throw
      expect(
        () async => await repository.addItem(itemWithInvalidHouse),
        throwsA(isA<Exception>()),
      );

      // Verify item was NOT inserted
      expect(
        () async => await repository.getItemById(itemWithInvalidHouse.id),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('DriftItemRepository - Space Filtering Methods', () {
    test('should correctly filter items by spaceId', () async {
      // === ARRANGE ===
      final houseId = 'test-house-space-filter';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House for Space Filter',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

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

      final now = DateTime.now();
      await repository.addItem(ItemModel(
        id: 'item-kitchen-1',
        houseId: houseId,
        name: 'Kitchen Item 1',
        category: ItemCategory.varie,
        spaceId: kitchenSpaceId,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.addItem(ItemModel(
        id: 'item-kitchen-2',
        houseId: houseId,
        name: 'Kitchen Item 2',
        category: ItemCategory.varie,
        spaceId: kitchenSpaceId,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.addItem(ItemModel(
        id: 'item-bedroom',
        houseId: houseId,
        name: 'Bedroom Item',
        category: ItemCategory.vestiti,
        spaceId: bedroomSpaceId,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.addItem(ItemModel(
        id: 'item-general-pool',
        houseId: houseId,
        name: 'General Pool Item',
        category: ItemCategory.varie,
        spaceId: null,
        createdAt: now,
        updatedAt: now,
      ));

      // === ACT ===
      final kitchenItems = await repository.getItemsBySpaceId(houseId, kitchenSpaceId);
      final bedroomItems = await repository.getItemsBySpaceId(houseId, bedroomSpaceId);
      final generalPoolItems = await repository.getItemsInGeneralPool(houseId);

      // === ASSERT ===
      expect(kitchenItems, hasLength(2));
      expect(kitchenItems.every((item) => item.spaceId == kitchenSpaceId), isTrue);

      expect(bedroomItems, hasLength(1));
      expect(bedroomItems.first.spaceId, equals(bedroomSpaceId));

      expect(generalPoolItems, hasLength(1));
      expect(generalPoolItems.first.spaceId, equals(null));
      expect(generalPoolItems.first.name, equals('General Pool Item'));
    });
  });
}
