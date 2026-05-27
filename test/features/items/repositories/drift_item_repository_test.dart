import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:pack_log/core/database/services/database_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/drift_item_repository.dart';
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
    repository = DriftItemRepository(
      database.itemsDao,
      databaseService,
      () => 'test-user-id',
    );
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('DriftItemRepository - Bidirectional Mapping Tests', () {
    test(
      'should correctly map ItemModel -> Companion -> ItemModel (addItem + getItemById)',
      () async {
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
      },
    );

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
        throwsA(isA<EntityNotFoundException>()),
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
      final house1Items = allItems
          .where((item) => item.houseId == house1Id)
          .toList();
      final house2Items = allItems
          .where((item) => item.houseId == house2Id)
          .toList();

      expect(house1Items, hasLength(2));
      expect(house2Items, hasLength(1));
    });
  });

  group('DriftItemRepository - Foreign Key Constraints', () {
    test(
      'should fail to add item with non-existent house (FK constraint)',
      () async {
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
          throwsA(isA<EntityNotFoundException>()),
        );
      },
    );
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
      await repository.addItem(
        ItemModel(
          id: 'item-kitchen-1',
          houseId: houseId,
          name: 'Kitchen Item 1',
          category: ItemCategory.varie,
          spaceId: kitchenSpaceId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.addItem(
        ItemModel(
          id: 'item-kitchen-2',
          houseId: houseId,
          name: 'Kitchen Item 2',
          category: ItemCategory.varie,
          spaceId: kitchenSpaceId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.addItem(
        ItemModel(
          id: 'item-bedroom',
          houseId: houseId,
          name: 'Bedroom Item',
          category: ItemCategory.vestiti,
          spaceId: bedroomSpaceId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.addItem(
        ItemModel(
          id: 'item-general-pool',
          houseId: houseId,
          name: 'General Pool Item',
          category: ItemCategory.varie,
          spaceId: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // === ACT ===
      final kitchenItems = await repository.getItemsBySpaceId(
        houseId,
        kitchenSpaceId,
      );
      final bedroomItems = await repository.getItemsBySpaceId(
        houseId,
        bedroomSpaceId,
      );
      final generalPoolItems = await repository.getItemsInGeneralPool(houseId);

      // === ASSERT ===
      expect(kitchenItems, hasLength(2));
      expect(
        kitchenItems.every((item) => item.spaceId == kitchenSpaceId),
        isTrue,
      );

      expect(bedroomItems, hasLength(1));
      expect(bedroomItems.first.spaceId, equals(bedroomSpaceId));

      expect(generalPoolItems, hasLength(1));
      expect(generalPoolItems.first.spaceId, equals(null));
      expect(generalPoolItems.first.name, equals('General Pool Item'));
    });
  });

  group('DriftItemRepository - Bulk Move Operations', () {
    test(
      'moveItemsToHouse should relocate items still at fromHouseId',
      () async {
        // === ARRANGE ===
        const houseAId = 'bulk-move-house-a';
        const houseBId = 'bulk-move-house-b';

        for (final id in [houseAId, houseBId]) {
          await database.housesDao.insertHouse(
            HousesCompanion.insert(
              id: id,
              name: 'House $id',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        final now = DateTime.now();
        final itemsInA = [
          ItemModel(
            id: 'bm-item-1',
            houseId: houseAId,
            name: 'Shirt',
            category: ItemCategory.vestiti,
            createdAt: now,
            updatedAt: now,
          ),
          ItemModel(
            id: 'bm-item-2',
            houseId: houseAId,
            name: 'Laptop',
            category: ItemCategory.elettronica,
            createdAt: now,
            updatedAt: now,
          ),
          ItemModel(
            id: 'bm-item-3',
            houseId: houseAId,
            name: 'Keys',
            category: ItemCategory.varie,
            createdAt: now,
            updatedAt: now,
          ),
        ];
        for (final item in itemsInA) {
          await repository.addItem(item);
        }

        // === ACT ===
        final ids = itemsInA.map((i) => i.id).toList();
        await repository.moveItemsToHouse(ids, houseAId, houseBId);

        // === ASSERT ===
        final inB = await repository.getItemsByHouseId(houseBId);
        expect(inB.length, 3);
        expect(inB.every((i) => i.houseId == houseBId), isTrue);
        expect(
          inB.every((i) => i.spaceId == null),
          isTrue,
          reason: 'All items must land in the general pool of house B',
        );

        final inA = await repository.getItemsByHouseId(houseAId);
        expect(inA, isEmpty);
      },
    );

    test('moveItemsToHouse MUST NOT move items not at fromHouseId '
        '(regression test for pull-to-refresh bug)', () async {
      // Verifies the critical fix: items belonging to an active trip (not at
      // the old completed trip's origin anymore) must not be incorrectly moved.
      //
      // Scenario:
      //   - T_old completed: A → C  (item was originally from A)
      //   - Item is now at B  (moved there by the active T_new: A → B)
      //   - Reprocessing T_old must NOT touch the item.

      // === ARRANGE ===
      const houseAId = 'reg-house-a';
      const houseBId = 'reg-house-b';
      const houseCId = 'reg-house-c';

      for (final id in [houseAId, houseBId, houseCId]) {
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: id,
            name: 'House $id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final now = DateTime.now();
      // Item is currently at B, not at A
      final item = ItemModel(
        id: 'reg-item',
        houseId: houseBId,
        name: 'Item at B',
        category: ItemCategory.varie,
        createdAt: now,
        updatedAt: now,
      );
      await repository.addItem(item);

      // === ACT: reprocess T_old (fromHouseId = A, item is at B) ===
      await repository.moveItemsToHouse([item.id], houseAId, houseCId);

      // === ASSERT: item still at B, NOT moved to C ===
      final itemsInB = await repository.getItemsByHouseId(houseBId);
      expect(
        itemsInB.length,
        1,
        reason: 'Item must remain in B — it was not at A when the query ran',
      );
      expect(itemsInB.first.id, item.id);

      final itemsInC = await repository.getItemsByHouseId(houseCId);
      expect(itemsInC, isEmpty, reason: 'Item must NOT have been moved to C');
    });

    test('moveItemsToHouse should be idempotent (move then re-run)', () async {
      // === ARRANGE ===
      const houseAId = 'idem-a';
      const houseBId = 'idem-b';
      for (final id in [houseAId, houseBId]) {
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: id,
            name: 'Idempotent House $id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final now = DateTime.now();
      final item = ItemModel(
        id: 'idem-item',
        houseId: houseAId,
        name: 'Idempotent',
        category: ItemCategory.varie,
        createdAt: now,
        updatedAt: now,
      );
      await repository.addItem(item);

      // === ACT: move once, then rerun (item is now at B, fromHouseId=A → no-op) ===
      await repository.moveItemsToHouse([item.id], houseAId, houseBId);
      await repository.moveItemsToHouse([item.id], houseAId, houseBId);

      // === ASSERT ===
      final inB = await repository.getItemsByHouseId(houseBId);
      expect(inB.length, 1);

      final inA = await repository.getItemsByHouseId(houseAId);
      expect(inA, isEmpty);
    });

    test('moveItemsToHouse with empty list should be a no-op', () async {
      await expectLater(
        repository.moveItemsToHouse([], 'any-a', 'any-b'),
        completes,
      );
    });

    test('moveItemsToHouse should only affect specified IDs', () async {
      // === ARRANGE ===
      const houseAId = 'selective-house-a';
      const houseBId = 'selective-house-b';

      for (final id in [houseAId, houseBId]) {
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: id,
            name: 'House $id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final now = DateTime.now();
      await repository.addItem(
        ItemModel(
          id: 'sel-1',
          houseId: houseAId,
          name: 'To Move',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.addItem(
        ItemModel(
          id: 'sel-2',
          houseId: houseAId,
          name: 'Stay Here',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // === ACT: move only sel-1 ===
      await repository.moveItemsToHouse(['sel-1'], houseAId, houseBId);

      // === ASSERT ===
      final inA = await repository.getItemsByHouseId(houseAId);
      expect(inA.length, 1);
      expect(inA.first.id, 'sel-2');

      final inB = await repository.getItemsByHouseId(houseBId);
      expect(inB.length, 1);
      expect(inB.first.id, 'sel-1');
    });

    test(
      'moveItemsToHouse with spaceId should persist space on moved item',
      () async {
        // === ARRANGE ===
        const houseAId = 'repo-spaceId-house-a';
        const houseBId = 'repo-spaceId-house-b';
        const spaceId = 'repo-spaceId-space-1';

        for (final id in [houseAId, houseBId]) {
          await database.housesDao.insertHouse(
            HousesCompanion.insert(
              id: id,
              name: 'House $id',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: spaceId,
            houseId: houseBId,
            name: 'Bedroom',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final now = DateTime.now();
        final item = ItemModel(
          id: 'repo-spaceId-item-1',
          houseId: houseAId,
          name: 'Jacket',
          category: ItemCategory.vestiti,
          createdAt: now,
          updatedAt: now,
        );
        await repository.addItem(item);

        // === ACT ===
        await repository.moveItemsToHouse(
          [item.id],
          houseAId,
          houseBId,
          spaceId: spaceId,
        );

        // === ASSERT ===
        final moved = await repository.getItemsByHouseId(houseBId);
        expect(moved.length, 1);
        expect(
          moved.first.spaceId,
          equals(spaceId),
          reason: 'spaceId must be propagated from repo to DAO',
        );
      },
    );
  });

  group('DriftItemRepository - Batch Operations', () {
    test(
      'insertMultipleItems should save all items in a single transaction',
      () async {
        // === ARRANGE ===
        final houseId = 'test-house-batch';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Batch Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final now = DateTime.now();
        final itemModels = [
          ItemModel(
            id: 'batch-item-1',
            houseId: houseId,
            name: 'Shirt',
            category: ItemCategory.vestiti,
            quantity: 3,
            createdAt: now,
            updatedAt: now,
          ),
          ItemModel(
            id: 'batch-item-2',
            houseId: houseId,
            name: 'Laptop',
            category: ItemCategory.elettronica,
            quantity: 1,
            createdAt: now,
            updatedAt: now,
          ),
          ItemModel(
            id: 'batch-item-3',
            houseId: houseId,
            name: 'Toothbrush',
            category: ItemCategory.toiletries,
            quantity: 2,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        // === ACT ===
        await repository.insertMultipleItems(itemModels);

        // === ASSERT ===
        final allItems = await repository.getAllItems();
        expect(allItems, hasLength(3));

        final shirt = allItems.firstWhere((i) => i.id == 'batch-item-1');
        expect(shirt.name, 'Shirt');
        expect(shirt.category, ItemCategory.vestiti);
        expect(shirt.quantity, 3);

        final laptop = allItems.firstWhere((i) => i.id == 'batch-item-2');
        expect(laptop.category, ItemCategory.elettronica);

        final toothbrush = allItems.firstWhere((i) => i.id == 'batch-item-3');
        expect(toothbrush.category, ItemCategory.toiletries);
        expect(toothbrush.quantity, 2);
      },
    );

    test('insertMultipleItems should handle empty list gracefully', () async {
      // === ARRANGE ===
      final emptyList = <ItemModel>[];

      // === ACT ===
      await repository.insertMultipleItems(emptyList);

      // === ASSERT ===
      final allItems = await repository.getAllItems();
      expect(allItems, isEmpty);
    });

    test('insertMultipleItems should throw on constraint violation', () async {
      // === ARRANGE ===
      final nonExistentHouseId = 'ghost-house';
      final now = DateTime.now();

      final itemModels = [
        ItemModel(
          id: 'orphan-item',
          houseId: nonExistentHouseId,
          name: 'Orphan Item',
          category: ItemCategory.varie,
          quantity: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // === ACT & ASSERT ===
      // Should throw exception due to foreign key constraint
      expect(() => repository.insertMultipleItems(itemModels), throwsException);
    });

    test(
      'insertMultipleItems should be atomic - rollback on partial failure',
      () async {
        // === ARRANGE ===
        final houseId = 'test-house-atomic';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Atomic Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final now = DateTime.now();

        // First, insert a valid item
        await repository.addItem(
          ItemModel(
            id: 'pre-existing-item',
            houseId: houseId,
            name: 'Pre-existing',
            category: ItemCategory.varie,
            quantity: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Try to insert batch with duplicate ID (should fail)
        final itemModels = [
          ItemModel(
            id: 'new-item-1',
            houseId: houseId,
            name: 'New Item',
            category: ItemCategory.varie,
            quantity: 1,
            createdAt: now,
            updatedAt: now,
          ),
          ItemModel(
            id: 'pre-existing-item', // DUPLICATE - violates PRIMARY KEY
            houseId: houseId,
            name: 'Duplicate',
            category: ItemCategory.varie,
            quantity: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        // === ACT & ASSERT ===
        expect(
          () => repository.insertMultipleItems(itemModels),
          throwsException,
        );

        // Verify transaction rolled back: only 1 item (pre-existing) should exist
        final allItems = await repository.getAllItems();
        expect(allItems, hasLength(1));
        expect(allItems.first.id, 'pre-existing-item');
      },
    );

    test(
      'insertMultipleItems should handle large batches efficiently',
      () async {
        // === ARRANGE ===
        final houseId = 'test-house-perf';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Performance Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final now = DateTime.now();
        final itemModels = List.generate(100, (index) {
          return ItemModel(
            id: 'perf-item-$index',
            houseId: houseId,
            name: 'Item $index',
            category: ItemCategory.varie,
            quantity: index % 10 + 1,
            createdAt: now,
            updatedAt: now,
          );
        });

        // === ACT ===
        final stopwatch = Stopwatch()..start();
        await repository.insertMultipleItems(itemModels);
        stopwatch.stop();

        // === ASSERT ===
        final allItems = await repository.getAllItems();
        expect(allItems, hasLength(100));

        // Batch insert should be significantly faster than individual inserts
        // (In-memory SQLite should handle 100 items in <1 second)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Batch insert took ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });
}
