import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for ItemsDao.
/// 
/// Focus: Testing batch insert operations and basic CRUD.
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('ItemsDao - Batch Insert Operations', () {
    test('insertMultipleItems should insert all items in a single transaction', () async {
      // === ARRANGE ===
      // Create a house (required for foreign key)
      final houseId = 'test-house-1';
      await database.housesDao.insertHouse(HousesCompanion.insert(
        id: houseId,
        name: 'Test House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Prepare multiple items
      final items = [
        ItemsCompanion.insert(
          id: 'item-1',
          houseId: houseId,
          name: 'T-shirt',
          category: 'vestiti',
          quantity: Value(3),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ItemsCompanion.insert(
          id: 'item-2',
          houseId: houseId,
          name: 'Laptop',
          category: 'elettronica',
          quantity: Value(1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ItemsCompanion.insert(
          id: 'item-3',
          houseId: houseId,
          name: 'Shampoo',
          category: 'toiletries',
          quantity: Value(2),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // === ACT ===
      await database.itemsDao.insertMultipleItems(items);

      // === ASSERT ===
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems.length, 3);

      final tshirt = allItems.firstWhere((i) => i.id == 'item-1');
      expect(tshirt.name, 'T-shirt');
      expect(tshirt.category, 'vestiti');
      expect(tshirt.quantity, 3);

      final laptop = allItems.firstWhere((i) => i.id == 'item-2');
      expect(laptop.name, 'Laptop');
      expect(laptop.category, 'elettronica');

      final shampoo = allItems.firstWhere((i) => i.id == 'item-3');
      expect(shampoo.name, 'Shampoo');
      expect(shampoo.category, 'toiletries');
      expect(shampoo.quantity, 2);
    });

    test('insertMultipleItems should handle empty list gracefully', () async {
      // === ARRANGE ===
      final emptyList = <ItemsCompanion>[];

      // === ACT ===
      await database.itemsDao.insertMultipleItems(emptyList);

      // === ASSERT ===
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty);
    });

    test('insertMultipleItems should handle large batches efficiently', () async {
      // === ARRANGE ===
      final houseId = 'test-house-1';
      await database.housesDao.insertHouse(HousesCompanion.insert(
        id: houseId,
        name: 'Test House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Generate 50 items to simulate a realistic bulk creation scenario
      final items = List.generate(50, (index) {
        return ItemsCompanion.insert(
          id: 'item-$index',
          houseId: houseId,
          name: 'Item $index',
          category: 'varie',
          quantity: Value(index % 5 + 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });

      // === ACT ===
      final stopwatch = Stopwatch()..start();
      await database.itemsDao.insertMultipleItems(items);
      stopwatch.stop();

      // === ASSERT ===
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems.length, 50);

      // Performance check: batch insert should be fast (<500ms for 50 items)
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Batch insert took ${stopwatch.elapsedMilliseconds}ms');
    });

    test('insertMultipleItems should respect foreign key constraints', () async {
      // === ARRANGE ===
      final nonExistentHouseId = 'non-existent-house';

      final items = [
        ItemsCompanion.insert(
          id: 'item-1',
          houseId: nonExistentHouseId,
          name: 'Orphan Item',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // === ACT & ASSERT ===
      // Should throw due to foreign key constraint (houseId must exist)
      expect(
        () => database.itemsDao.insertMultipleItems(items),
        throwsA(isA<Exception>()),
      );
    });

    test('moveItemsToHouse should move items still at fromHouseId', () async {
      // === ARRANGE ===
      final houseAId = 'house-origin';
      final houseBId = 'house-destination';

      for (final id in [houseAId, houseBId]) {
        await database.housesDao.insertHouse(HousesCompanion.insert(
          id: id,
          name: 'House $id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      final itemIds = ['move-item-1', 'move-item-2', 'move-item-3'];
      for (final id in itemIds) {
        await database.itemsDao.insertItem(ItemsCompanion.insert(
          id: id,
          houseId: houseAId,
          name: 'Item $id',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // === ACT ===
      await database.itemsDao.moveItemsToHouse(itemIds, houseAId, houseBId);

      // === ASSERT ===
      final movedItems = await database.itemsDao.getItemsByHouseId(houseBId);
      expect(movedItems.length, 3);
      expect(movedItems.every((i) => i.houseId == houseBId), isTrue);
      expect(movedItems.every((i) => i.spaceId == null), isTrue,
          reason: 'spaceId must be cleared on transfer');

      final remainingInA = await database.itemsDao.getItemsByHouseId(houseAId);
      expect(remainingInA, isEmpty);
    });

    test(
        'moveItemsToHouse MUST NOT move items not at fromHouseId '
        '(regression test for pull-to-refresh bug)', () async {
      // This test verifies the critical fix: items already relocated to a
      // different house (e.g., because they are currently on an active trip)
      // must NOT be moved when a previously-completed trip is reprocessed.
      //
      // Scenario:
      //   - T_old completed: House A → House C (item is in the candidate list)
      //   - Item is currently at House B (moved there by an active trip)
      //   - Reprocessing T_old must NOT move the item to House C.

      // === ARRANGE ===
      final houseAId = 'house-a';
      final houseBId = 'house-b';
      final houseCId = 'house-c';

      for (final id in [houseAId, houseBId, houseCId]) {
        await database.housesDao.insertHouse(HousesCompanion.insert(
          id: id,
          name: 'House $id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // Item is currently in House B (relocated, not House A anymore)
      await database.itemsDao.insertItem(ItemsCompanion.insert(
        id: 'relocated-item',
        houseId: houseBId,
        name: 'Relocated Item',
        category: 'varie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // === ACT: reprocess T_old (completed, A → C) ===
      // fromHouseId = houseAId but item is at houseB → WHERE clause mismatch
      await database.itemsDao
          .moveItemsToHouse(['relocated-item'], houseAId, houseCId);

      // === ASSERT: item must remain in House B, untouched ===
      final itemsInB = await database.itemsDao.getItemsByHouseId(houseBId);
      expect(itemsInB.length, 1, reason: 'Item must still be in House B');
      expect(itemsInB.first.id, 'relocated-item');

      final itemsInC = await database.itemsDao.getItemsByHouseId(houseCId);
      expect(itemsInC, isEmpty,
          reason: 'Item must NOT have been moved to House C');
    });

    test('moveItemsToHouse should be idempotent', () async {
      // === ARRANGE ===
      final houseAId = 'idem-house-a';
      final houseBId = 'idem-house-b';
      for (final id in [houseAId, houseBId]) {
        await database.housesDao.insertHouse(HousesCompanion.insert(
          id: id,
          name: 'House $id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      await database.itemsDao.insertItem(ItemsCompanion.insert(
        id: 'idempotent-item',
        houseId: houseAId,
        name: 'Idempotent Item',
        category: 'varie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // === ACT: move once, then rerun (simulates repeated TripNotifier builds) ===
      await database.itemsDao
          .moveItemsToHouse(['idempotent-item'], houseAId, houseBId);
      // Second call: item is now at B, fromHouseId is still A → no-op
      await database.itemsDao
          .moveItemsToHouse(['idempotent-item'], houseAId, houseBId);

      // === ASSERT ===
      final itemsInB = await database.itemsDao.getItemsByHouseId(houseBId);
      expect(itemsInB.length, 1,
          reason: 'Exactly one item in B after idempotent calls');

      final itemsInA = await database.itemsDao.getItemsByHouseId(houseAId);
      expect(itemsInA, isEmpty);
    });

    test('moveItemsToHouse should skip gracefully on empty list', () async {
      await database.itemsDao.moveItemsToHouse([], 'any-a', 'any-b');
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty);
    });

    test('insertMultipleItems should be atomic - all or nothing', () async {
      // === ARRANGE ===
      final houseId = 'test-house-1';
      await database.housesDao.insertHouse(HousesCompanion.insert(
        id: houseId,
        name: 'Test House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Create a mix of valid and invalid items (invalid due to duplicate ID)
      final items = [
        ItemsCompanion.insert(
          id: 'item-1',
          houseId: houseId,
          name: 'Valid Item 1',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ItemsCompanion.insert(
          id: 'item-1', // Duplicate ID - violates PRIMARY KEY
          houseId: houseId,
          name: 'Invalid Duplicate',
          category: 'varie',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // === ACT & ASSERT ===
      // Should throw due to duplicate primary key
      expect(
        () => database.itemsDao.insertMultipleItems(items),
        throwsA(isA<Exception>()),
      );

      // Verify transaction rolled back: NO items should be inserted
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty, reason: 'Transaction should rollback on error');
    });
  });
}
