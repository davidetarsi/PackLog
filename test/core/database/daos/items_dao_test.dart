import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/features/items/model/item_model.dart';
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
    test(
      'insertMultipleItems should insert all items in a single transaction',
      () async {
        // === ARRANGE ===
        // Create a house (required for foreign key)
        final houseId = 'test-house-1';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Prepare multiple items
        final items = [
          ItemsCompanion.insert(
            id: 'item-1',
            houseId: houseId,
            name: 'T-shirt',
            category: ItemCategory.vestiti,
            quantity: Value(3),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ItemsCompanion.insert(
            id: 'item-2',
            houseId: houseId,
            name: 'Laptop',
            category: ItemCategory.elettronica,
            quantity: Value(1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ItemsCompanion.insert(
            id: 'item-3',
            houseId: houseId,
            name: 'Shampoo',
            category: ItemCategory.toiletries,
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
        expect(tshirt.category, ItemCategory.vestiti);
        expect(tshirt.quantity, 3);

        final laptop = allItems.firstWhere((i) => i.id == 'item-2');
        expect(laptop.name, 'Laptop');
        expect(laptop.category, ItemCategory.elettronica);

        final shampoo = allItems.firstWhere((i) => i.id == 'item-3');
        expect(shampoo.name, 'Shampoo');
        expect(shampoo.category, ItemCategory.toiletries);
        expect(shampoo.quantity, 2);
      },
    );

    test('insertMultipleItems should handle empty list gracefully', () async {
      // === ARRANGE ===
      final emptyList = <ItemsCompanion>[];

      // === ACT ===
      await database.itemsDao.insertMultipleItems(emptyList);

      // === ASSERT ===
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty);
    });

    test(
      'insertMultipleItems should handle large batches efficiently',
      () async {
        // === ARRANGE ===
        final houseId = 'test-house-1';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Generate 50 items to simulate a realistic bulk creation scenario
        final items = List.generate(50, (index) {
          return ItemsCompanion.insert(
            id: 'item-$index',
            houseId: houseId,
            name: 'Item $index',
            category: ItemCategory.varie,
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
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason: 'Batch insert took ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );

    test(
      'insertMultipleItems should respect foreign key constraints',
      () async {
        // === ARRANGE ===
        final nonExistentHouseId = 'non-existent-house';

        final items = [
          ItemsCompanion.insert(
            id: 'item-1',
            houseId: nonExistentHouseId,
            name: 'Orphan Item',
            category: ItemCategory.varie,
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
      },
    );

    test('moveItemsToHouse should move items still at fromHouseId', () async {
      // === ARRANGE ===
      final houseAId = 'house-origin';
      final houseBId = 'house-destination';

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

      final itemIds = ['move-item-1', 'move-item-2', 'move-item-3'];
      for (final id in itemIds) {
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: id,
            houseId: houseAId,
            name: 'Item $id',
            category: ItemCategory.varie,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // === ACT ===
      await database.itemsDao.moveItemsToHouse(itemIds, houseAId, houseBId);

      // === ASSERT ===
      final movedItems = await database.itemsDao.getItemsByHouseId(houseBId);
      expect(movedItems.length, 3);
      expect(movedItems.every((i) => i.houseId == houseBId), isTrue);
      expect(
        movedItems.every((i) => i.spaceId == null),
        isTrue,
        reason: 'spaceId must be cleared on transfer',
      );
      expect(
        movedItems.every((i) => i.syncStatus == SyncStatus.pendingUpdate),
        isTrue,
        reason: 'moved items must be marked pendingUpdate for sync',
      );

      final remainingInA = await database.itemsDao.getItemsByHouseId(houseAId);
      expect(remainingInA, isEmpty);
    });

    test('moveItemsToHouse MUST NOT move items not at fromHouseId '
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
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: id,
            name: 'House $id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // Item is currently in House B (relocated, not House A anymore)
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'relocated-item',
          houseId: houseBId,
          name: 'Relocated Item',
          category: ItemCategory.varie,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // === ACT: reprocess T_old (completed, A → C) ===
      // fromHouseId = houseAId but item is at houseB → WHERE clause mismatch
      await database.itemsDao.moveItemsToHouse(
        ['relocated-item'],
        houseAId,
        houseCId,
      );

      // === ASSERT: item must remain in House B, untouched ===
      final itemsInB = await database.itemsDao.getItemsByHouseId(houseBId);
      expect(itemsInB.length, 1, reason: 'Item must still be in House B');
      expect(itemsInB.first.id, 'relocated-item');

      final itemsInC = await database.itemsDao.getItemsByHouseId(houseCId);
      expect(
        itemsInC,
        isEmpty,
        reason: 'Item must NOT have been moved to House C',
      );
    });

    test('moveItemsToHouse should be idempotent', () async {
      // === ARRANGE ===
      final houseAId = 'idem-house-a';
      final houseBId = 'idem-house-b';
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

      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'idempotent-item',
          houseId: houseAId,
          name: 'Idempotent Item',
          category: ItemCategory.varie,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // === ACT: move once, then rerun (simulates repeated TripNotifier builds) ===
      await database.itemsDao.moveItemsToHouse(
        ['idempotent-item'],
        houseAId,
        houseBId,
      );
      // Second call: item is now at B, fromHouseId is still A → no-op
      await database.itemsDao.moveItemsToHouse(
        ['idempotent-item'],
        houseAId,
        houseBId,
      );

      // === ASSERT ===
      final itemsInB = await database.itemsDao.getItemsByHouseId(houseBId);
      expect(
        itemsInB.length,
        1,
        reason: 'Exactly one item in B after idempotent calls',
      );

      final itemsInA = await database.itemsDao.getItemsByHouseId(houseAId);
      expect(itemsInA, isEmpty);
    });

    test('moveItemsToHouse should skip gracefully on empty list', () async {
      await database.itemsDao.moveItemsToHouse([], 'any-a', 'any-b');
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty);
    });

    test(
      'moveItemsToHouse with spaceId should assign space to moved items',
      () async {
        // === ARRANGE ===
        const houseAId = 'dao-spaceId-house-a';
        const houseBId = 'dao-spaceId-house-b';
        const spaceId = 'dao-spaceId-space-1';

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
        const itemId = 'dao-spaceId-item-1';
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: itemId,
            houseId: houseAId,
            name: 'Shirt',
            category: ItemCategory.vestiti,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // === ACT ===
        await database.itemsDao.moveItemsToHouse(
          [itemId],
          houseAId,
          houseBId,
          spaceId: spaceId,
        );

        // === ASSERT ===
        final moved = await database.itemsDao.getItemsByHouseId(houseBId);
        expect(moved.length, 1);
        expect(
          moved.first.spaceId,
          equals(spaceId),
          reason: 'spaceId must be set when passed to moveItemsToHouse',
        );
      },
    );

    test('insertMultipleItems should be atomic - all or nothing', () async {
      // === ARRANGE ===
      final houseId = 'test-house-1';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Test House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Create a mix of valid and invalid items (invalid due to duplicate ID)
      final items = [
        ItemsCompanion.insert(
          id: 'item-1',
          houseId: houseId,
          name: 'Valid Item 1',
          category: ItemCategory.varie,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ItemsCompanion.insert(
          id: 'item-1', // Duplicate ID - violates PRIMARY KEY
          houseId: houseId,
          name: 'Invalid Duplicate',
          category: ItemCategory.varie,
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

  group('ItemsDao - incrementSyncRetry', () {
    test('non modifica updatedAt (pivot LWW)', () async {
      final t0 = DateTime(2026, 5, 1, 8, 0);
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-retry-item',
          name: 'Casa',
          createdAt: t0,
          updatedAt: t0,
        ),
      );
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'i-retry',
          houseId: 'h-retry-item',
          name: 'Oggetto',
          category: ItemCategory.varie,
          createdAt: t0,
          updatedAt: t0,
        ),
      );

      await database.itemsDao.incrementSyncRetry('i-retry', 'boom');

      final item = await database.itemsDao.findItemById('i-retry');
      expect(item!.updatedAt, equals(t0),
          reason: 'il retry bookkeeping non deve toccare il pivot LWW');
      expect(item.syncRetryCount, equals(1));
      expect(item.lastSyncError, equals('boom'));
      expect(item.nextSyncAttemptAt, isNotNull);
    });
  });

  group('ItemsDao - Sync Operations', () {
    late String houseId;

    setUp(() async {
      houseId = 'sync-house';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Sync House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    Future<void> insertItem(
      String id, {
      SyncStatus status = SyncStatus.pendingCreate,
    }) async {
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: id,
          houseId: houseId,
          name: 'Item $id',
          category: ItemCategory.varie,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (status != SyncStatus.pendingCreate) {
        await (database.update(database.items)..where((i) => i.id.equals(id)))
            .write(ItemsCompanion(syncStatus: Value(status)));
      }
    }

    test(
      'getPendingSyncItems returns only non-synced items below retry limit',
      () async {
        await insertItem('pending-1');
        await insertItem('pending-2', status: SyncStatus.pendingUpdate);
        await insertItem('synced-1', status: SyncStatus.synced);

        final pending = await database.itemsDao.getPendingSyncItems();

        expect(pending, hasLength(2));
        final ids = pending.map((i) => i.id).toSet();
        expect(ids, containsAll(['pending-1', 'pending-2']));
        expect(ids, isNot(contains('synced-1')));
      },
    );

    test('getPendingSyncItems excludes items exceeding maxRetries', () async {
      await insertItem('retry-exhausted');
      await (database.update(database.items)
            ..where((i) => i.id.equals('retry-exhausted')))
          .write(const ItemsCompanion(syncRetryCount: Value(5)));

      final pending = await database.itemsDao.getPendingSyncItems(
        maxRetries: 5,
      );
      expect(pending, isEmpty);
    });

    test(
      'getPendingSyncItems includes soft-deleted items (to propagate deletion to server)',
      () async {
        await insertItem('deleted-pending');
        await database.itemsDao.deleteItem('deleted-pending');

        final pending = await database.itemsDao.getPendingSyncItems();
        expect(pending, hasLength(1));
        expect(pending.first.id, equals('deleted-pending'));
        expect(pending.first.isDeleted, isTrue);
      },
    );

    test('getPendingSyncItems respects nextSyncAttemptAt cooldown', () async {
      await insertItem('cooldown-item');
      final future = DateTime.now().add(const Duration(hours: 1));
      await (database.update(database.items)
            ..where((i) => i.id.equals('cooldown-item')))
          .write(ItemsCompanion(nextSyncAttemptAt: Value(future)));

      final pending = await database.itemsDao.getPendingSyncItems();
      expect(pending, isEmpty);
    });

    test('markItemAsSynced resets retry state and sets lastSyncedAt', () async {
      await insertItem('to-sync');
      await database.itemsDao.incrementSyncRetry('to-sync', 'timeout');

      final serverTime = DateTime(2026, 4, 28, 12, 0);
      await database.itemsDao.markItemAsSynced('to-sync', serverTime);

      final item = await database.itemsDao.getItemById('to-sync');
      expect(item, isA<Item>());
      expect(item!.syncStatus, equals(SyncStatus.synced));
      expect(item.syncRetryCount, equals(0));
      expect(item.lastSyncError, isNull);
      expect(item.lastSyncedAt, equals(serverTime));
      expect(item.nextSyncAttemptAt, isNull);
    });

    test('incrementSyncRetry increments count and sets backoff', () async {
      await insertItem('retry-me');

      await database.itemsDao.incrementSyncRetry('retry-me', 'network timeout');
      var item = await database.itemsDao.getItemById('retry-me');
      expect(item!.syncRetryCount, equals(1));
      expect(item.lastSyncError, equals('network timeout'));
      expect(item.nextSyncAttemptAt, isNotNull);

      await database.itemsDao.incrementSyncRetry('retry-me', 'server 500');
      item = await database.itemsDao.getItemById('retry-me');
      expect(item!.syncRetryCount, equals(2));
      expect(item.lastSyncError, equals('server 500'));
    });

    test('incrementSyncRetry is a no-op for non-existent item', () async {
      await database.itemsDao.incrementSyncRetry('ghost-id', 'error');
    });

    test('new items default to pendingCreate sync status', () async {
      await insertItem('fresh');
      final item = await database.itemsDao.getItemById('fresh');
      expect(item!.syncStatus, equals(SyncStatus.pendingCreate));
      expect(item.syncRetryCount, equals(0));
      expect(item.lastSyncError, isNull);
    });

    test('markItemAsSynced overwrites updatedAt with server timestamp '
        '(post fix #6: server-side updated_at)', () async {
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'i-server-ts',
          houseId: houseId,
          name: 'Item',
          category: ItemCategory.varie,
          createdAt: DateTime(2026, 5, 1, 7, 0),
          updatedAt: DateTime(2026, 5, 1, 8, 0),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      final serverTs = DateTime(2026, 5, 1, 12, 0);
      await database.itemsDao.markItemAsSynced('i-server-ts', serverTs);

      final item = await database.itemsDao.getItemById('i-server-ts');
      expect(
        item!.updatedAt,
        equals(serverTs),
        reason:
            'updatedAt deve essere allineato al server timestamp per '
            'rendere immune la LWW al clock drift del client',
      );
      expect(item.syncStatus, equals(SyncStatus.synced));
      expect(item.lastSyncedAt, equals(serverTs));
    });

    test('resetSyncRetries clears retry counter, error and backoff', () async {
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'i-blocked',
          houseId: houseId,
          name: 'Item',
          category: ItemCategory.varie,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await database.itemsDao.incrementSyncRetry('i-blocked', 'boom');
      }

      final reset = await database.itemsDao.resetSyncRetries();
      expect(reset, greaterThan(0));

      final item = await database.itemsDao.getItemById('i-blocked');
      expect(item!.syncRetryCount, equals(0));
      expect(item.lastSyncError, isNull);
      expect(item.nextSyncAttemptAt, isNull);
    });

    test('wipeAll physically removes every item row', () async {
      await insertItem('i-1');
      await insertItem('i-2', status: SyncStatus.synced);

      await database.itemsDao.wipeAll();

      final allRows = await database.select(database.items).get();
      expect(allRows, isEmpty);
    });

    test(
      'updateItem preserves sync metadata when companion omits sync fields',
      () async {
        final originalSyncedAt = DateTime(2026, 5, 1, 8, 0);
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: 'i-keep-sync',
            houseId: houseId,
            name: 'Original',
            category: ItemCategory.varie,
            createdAt: DateTime(2026, 5, 1, 7, 0),
            updatedAt: DateTime(2026, 5, 1, 7, 0),
            syncStatus: const Value(SyncStatus.synced),
            syncRetryCount: const Value(3),
            lastSyncedAt: Value(originalSyncedAt),
          ),
        );

        await database.itemsDao.updateItem(
          ItemsCompanion(
            id: const Value('i-keep-sync'),
            houseId: Value(houseId),
            name: const Value('Renamed'),
            category: const Value(ItemCategory.varie),
            createdAt: Value(DateTime(2026, 5, 1, 7, 0)),
            updatedAt: Value(DateTime(2026, 5, 1, 10, 0)),
          ),
        );

        final item = await database.itemsDao.getItemById('i-keep-sync');
        expect(item!.name, equals('Renamed'));
        expect(
          item.lastSyncedAt,
          equals(originalSyncedAt),
          reason: 'updateItem must not reset lastSyncedAt',
        );
        expect(
          item.syncRetryCount,
          equals(3),
          reason: 'updateItem must not reset syncRetryCount',
        );
        expect(
          item.syncStatus,
          equals(SyncStatus.pendingUpdate),
          reason: 'updateItem must mark the record pending so it gets pushed',
        );
      },
    );
  });
}
