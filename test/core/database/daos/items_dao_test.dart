import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/core/database/database.dart';
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
