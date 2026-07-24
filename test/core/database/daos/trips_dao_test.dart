import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for TripsDao.
///
/// Tests the DAO operations for trips including:
/// - CRUD operations on trips
/// - Trip items (snapshot) management
/// - Many-to-many luggage associations
/// - Transaction integrity and foreign key constraints
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('TripsDao - Complex Transaction with Items and Luggages', () {
    test(
      'should insert a trip with snapshot items and luggage links within a transaction',
      () async {
        // === ARRANGE ===
        // Step 1: Create required parent entities due to foreign key constraints

        // Create a house (required for luggage foreign key)
        final houseId = 'test-house-1';
        final houseCompanion = HousesCompanion.insert(
          id: houseId,
          name: 'Test House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await database.housesDao.insertHouse(houseCompanion);

        // Create a luggage associated with the house
        final luggageId = 'test-luggage-1';
        final luggageCompanion = LuggagesCompanion.insert(
          id: luggageId,
          houseId: houseId,
          name: 'Test Suitcase',
          sizeType: LuggageSize.holdBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await database.luggagesDao.insertLuggage(luggageCompanion);

        // Create a second luggage for testing multiple associations
        final luggage2Id = 'test-luggage-2';
        final luggage2Companion = LuggagesCompanion.insert(
          id: luggage2Id,
          houseId: houseId,
          name: 'Test Backpack',
          sizeType: LuggageSize.smallBackpack,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await database.luggagesDao.insertLuggage(luggage2Companion);

        // Step 2: Prepare trip data
        final tripId = 'test-trip-1';
        final tripCompanion = TripsCompanion.insert(
          id: tripId,
          name: 'Summer Vacation',
          locationDisplayName: const Value('Beach Resort'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Step 3: Prepare trip snapshot items (items user wants to bring)
        final tripItems = [
          TripItemEntriesCompanion.insert(
            id: 'trip-item-1',
            tripId: tripId,
            name: 'Sunscreen',
            category: ItemCategory.toiletries,
            quantity: Value(2),
            originHouseId: Value(houseId),
          ),
          TripItemEntriesCompanion.insert(
            id: 'trip-item-2',
            tripId: tripId,
            name: 'Beach Towel',
            category: ItemCategory.vestiti,
            quantity: Value(1),
            originHouseId: Value(houseId),
          ),
          TripItemEntriesCompanion.insert(
            id: 'trip-item-3',
            tripId: tripId,
            name: 'Sunglasses',
            category: ItemCategory.varie,
            quantity: Value(1),
            originHouseId: Value(houseId),
          ),
        ];

        // Step 4: Prepare luggage IDs to associate with the trip
        final luggageIdsToLink = [luggageId, luggage2Id];

        // === ACT ===
        // Execute the transaction: insert trip + items + luggage links
        await database.transaction(() async {
          // Insert the trip
          await database.tripsDao.insertTrip(tripCompanion);

          // Insert all trip items (snapshot)
          await database.tripsDao.insertMultipleTripItems(tripItems);

          // Link luggages to the trip via junction table
          for (final lugId in luggageIdsToLink) {
            await database.luggagesDao.linkLuggageToTrip(tripId, lugId);
          }
        });

        // === ASSERT ===
        // Verify trip was inserted
        final retrievedTrip = await database.tripsDao.getTripById(tripId);
        expect(retrievedTrip, isA<Trip>());
        expect(retrievedTrip!.id, equals(tripId));
        expect(retrievedTrip.name, equals('Summer Vacation'));
        expect(retrievedTrip.locationDisplayName, equals('Beach Resort'));

        // Verify trip items were inserted with correct foreign keys
        final retrievedItems = await database.tripsDao.getTripItemsByTripId(
          tripId,
        );
        expect(retrievedItems, hasLength(3));

        // Verify all items have correct tripId foreign key
        for (final item in retrievedItems) {
          expect(item.tripId, equals(tripId));
        }

        // Verify specific item details
        final sunscreenItem = retrievedItems.firstWhere(
          (item) => item.name == 'Sunscreen',
        );
        expect(sunscreenItem.category, equals(ItemCategory.toiletries));
        expect(sunscreenItem.quantity, equals(2));
        expect(sunscreenItem.originHouseId, equals(houseId));
        expect(sunscreenItem.isChecked, isFalse); // Default value

        final towelItem = retrievedItems.firstWhere(
          (item) => item.name == 'Beach Towel',
        );
        expect(towelItem.quantity, equals(1));

        final sunglassesItem = retrievedItems.firstWhere(
          (item) => item.name == 'Sunglasses',
        );
        // 'accessori' non esiste nell'enum — il companion era già corretto a ItemCategory.varie
        expect(sunglassesItem.category, equals(ItemCategory.varie));

        // Verify luggage associations via junction table
        final retrievedLuggages = await database.luggagesDao.getLuggagesByTrip(
          tripId,
        );
        expect(retrievedLuggages, hasLength(2));

        // Verify luggage IDs are correct
        final retrievedLuggageIds = retrievedLuggages.map((l) => l.id).toSet();
        expect(retrievedLuggageIds, containsAll([luggageId, luggage2Id]));

        // Verify luggage details
        final suitcase = retrievedLuggages.firstWhere(
          (l) => l.name == 'Test Suitcase',
        );
        expect(suitcase.sizeType, equals(LuggageSize.holdBaggage));
        expect(suitcase.houseId, equals(houseId));

        final backpack = retrievedLuggages.firstWhere(
          (l) => l.name == 'Test Backpack',
        );
        expect(backpack.sizeType, equals(LuggageSize.smallBackpack));
      },
    );

    test('should maintain transaction integrity on rollback', () async {
      // === ARRANGE ===
      // Create a house
      final houseId = 'test-house-rollback';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Rollback House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final tripId = 'test-trip-rollback';
      final tripCompanion = TripsCompanion.insert(
        id: tripId,
        name: 'Failed Trip',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tripItem = TripItemEntriesCompanion.insert(
        id: 'trip-item-rollback',
        tripId: tripId,
        name: 'Test Item',
        category: ItemCategory.varie,
      );

      // === ACT & ASSERT ===
      // Attempt transaction that will fail
      await expectLater(
        database.transaction(() async {
          // Insert trip
          await database.tripsDao.insertTrip(tripCompanion);

          // Insert item
          await database.tripsDao.insertTripItem(tripItem);

          // Force transaction rollback by throwing an exception
          throw Exception('Simulated error during transaction');
        }),
        throwsException,
      );

      // Verify rollback: trip should NOT exist
      final trip = await database.tripsDao.getTripById(tripId);
      expect(trip, equals(null));

      // Verify rollback: trip items should NOT exist
      final items = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(items, isEmpty);
    });

    test(
      'should enforce foreign key constraints when inserting trip items',
      () async {
        // === ARRANGE ===
        // DO NOT create a trip - this will violate foreign key constraint
        final nonExistentTripId = 'non-existent-trip';

        final tripItem = TripItemEntriesCompanion.insert(
          id: 'orphan-item',
          tripId: nonExistentTripId, // This tripId does not exist
          name: 'Orphan Item',
          category: ItemCategory.varie,
        );

        // === ACT & ASSERT ===
        // Attempt to insert item with invalid foreign key
        // Should fail because PRAGMA foreign_keys = ON
        expect(
          () async => await database.tripsDao.insertTripItem(tripItem),
          throwsA(isA<Exception>()),
        );

        // Verify item was NOT inserted
        final items = await database.tripsDao.getTripItemsByTripId(
          nonExistentTripId,
        );
        expect(items, isEmpty);
      },
    );

    test(
      'should enforce composite primary key constraint on trip-luggage junction table',
      () async {
        // === ARRANGE ===
        // Create necessary entities
        final houseId = 'test-house-pk';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'PK Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final luggageId = 'test-luggage-pk';
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: luggageId,
            houseId: houseId,
            name: 'PK Test Luggage',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final tripId = 'test-trip-pk';
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: tripId,
            name: 'PK Test Trip',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Link luggage to trip (first time - should succeed)
        await database.luggagesDao.linkLuggageToTrip(tripId, luggageId);

        // === ACT & ASSERT ===
        // Attempt to insert the same (tripId, luggageId) pair again
        // Should fail due to composite primary key constraint
        expect(
          () async =>
              await database.luggagesDao.linkLuggageToTrip(tripId, luggageId),
          throwsA(isA<Exception>()),
        );

        // Verify only one entry exists
        final luggages = await database.luggagesDao.getLuggagesByTrip(tripId);
        expect(luggages, hasLength(1));
      },
    );
  });

  group('TripsDao - Append Items (idempotent)', () {
    test(
      'insertTripItemsIgnoringDuplicates adds new items and ignores duplicates',
      () async {
        // === ARRANGE ===
        final houseId = 'append-house-1';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final tripId = 'append-trip-1';
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: tripId,
            name: 'Weekend Trip',
            locationDisplayName: const Value('Mountains'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Trip already has one item.
        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'item-1',
            tripId: tripId,
            name: 'Jacket',
            category: ItemCategory.vestiti,
            quantity: Value(1),
            originHouseId: Value(houseId),
          ),
        );

        // === ACT ===
        // Re-adding item-1 (duplicate) plus a genuinely new item-2.
        await database.tripsDao.insertTripItemsIgnoringDuplicates([
          TripItemEntriesCompanion.insert(
            id: 'item-1',
            tripId: tripId,
            name: 'Jacket',
            category: ItemCategory.vestiti,
            quantity: Value(1),
            originHouseId: Value(houseId),
          ),
          TripItemEntriesCompanion.insert(
            id: 'item-2',
            tripId: tripId,
            name: 'Boots',
            category: ItemCategory.vestiti,
            quantity: Value(1),
            originHouseId: Value(houseId),
          ),
        ]);

        // === ASSERT ===
        final items = await database.tripsDao.getTripItemsByTripId(tripId);
        expect(items.length, 2);
        expect(items.map((i) => i.id).toSet(), {'item-1', 'item-2'});
      },
    );

    test(
      'insertTripItemsIgnoringDuplicates is a no-op for an empty list',
      () async {
        // Should simply not throw.
        await database.tripsDao.insertTripItemsIgnoringDuplicates([]);
      },
    );
  });

  group('TripsDao - CRUD Operations', () {
    test('should insert and retrieve a trip', () async {
      // === ARRANGE ===
      final tripId = 'trip-crud-1';
      final tripCompanion = TripsCompanion.insert(
        id: tripId,
        name: 'Weekend Getaway',
        locationDisplayName: Value('Mountain Cabin'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      await database.tripsDao.insertTrip(tripCompanion);
      final retrieved = await database.tripsDao.getTripById(tripId);

      // === ASSERT ===
      expect(retrieved, isA<Trip>());
      expect(retrieved!.id, equals(tripId));
      expect(retrieved.name, equals('Weekend Getaway'));
      expect(retrieved.locationDisplayName, equals('Mountain Cabin'));
    });

    test('should update an existing trip', () async {
      // === ARRANGE ===
      final tripId = 'trip-update-1';
      final originalTrip = TripsCompanion.insert(
        id: tripId,
        name: 'Original Name',
        locationDisplayName: Value('Original Destination'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await database.tripsDao.insertTrip(originalTrip);

      // === ACT ===
      final updatedTrip = TripsCompanion(
        id: Value(tripId),
        name: Value('Updated Name'),
        locationDisplayName: Value('Updated Destination'),
        createdAt: Value(DateTime.now()), // Required for replace
        updatedAt: Value(DateTime.now()),
      );

      final updateResult = await database.tripsDao.updateTrip(updatedTrip);
      final retrieved = await database.tripsDao.getTripById(tripId);

      // === ASSERT ===
      expect(updateResult, isTrue);
      expect(retrieved!.name, equals('Updated Name'));
      expect(retrieved.locationDisplayName, equals('Updated Destination'));
    });

    test('should delete a trip and cascade delete its items', () async {
      // === ARRANGE ===
      final tripId = 'trip-delete-1';

      // Insert trip
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          name: 'Trip to Delete',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Insert items for the trip
      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: 'item-to-delete-1',
          tripId: tripId,
          name: 'Item 1',
          category: ItemCategory.varie,
        ),
      );

      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: 'item-to-delete-2',
          tripId: tripId,
          name: 'Item 2',
          category: ItemCategory.varie,
        ),
      );

      // Verify items exist before deletion
      final itemsBeforeDelete = await database.tripsDao.getTripItemsByTripId(
        tripId,
      );
      expect(itemsBeforeDelete, hasLength(2));

      // === ACT ===
      final deleteResult = await database.tripsDao.deleteTrip(tripId);

      // === ASSERT ===
      expect(deleteResult, equals(1)); // 1 row deleted

      // Verify trip is deleted
      final tripAfterDelete = await database.tripsDao.getTripById(tripId);
      expect(tripAfterDelete, equals(null));

      // Verify items are cascade deleted (ON DELETE CASCADE)
      final itemsAfterDelete = await database.tripsDao.getTripItemsByTripId(
        tripId,
      );
      expect(itemsAfterDelete, isEmpty);
    });

    test('should retrieve all trips', () async {
      // === ARRANGE ===
      final now = DateTime.now();

      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 'trip-all-1',
          name: 'Trip 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 'trip-all-2',
          name: 'Trip 2',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 'trip-all-3',
          name: 'Trip 3',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // === ACT ===
      final allTrips = await database.tripsDao.getAllTrips();

      // === ASSERT ===
      expect(allTrips, hasLength(3));

      final tripNames = allTrips.map((t) => t.name).toList();
      expect(tripNames, containsAll(['Trip 1', 'Trip 2', 'Trip 3']));
    });
  });

  group('TripsDao - Trip Items Management', () {
    test('should replace all trip items atomically', () async {
      // === ARRANGE ===
      final tripId = 'trip-replace-items';

      // Create trip
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          name: 'Replace Items Trip',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Insert initial items
      final initialItems = [
        TripItemEntriesCompanion.insert(
          id: 'initial-item-1',
          tripId: tripId,
          name: 'Old Item 1',
          category: ItemCategory.varie,
        ),
        TripItemEntriesCompanion.insert(
          id: 'initial-item-2',
          tripId: tripId,
          name: 'Old Item 2',
          category: ItemCategory.varie,
        ),
      ];

      await database.tripsDao.insertMultipleTripItems(initialItems);

      // Verify initial state
      final itemsBeforeReplace = await database.tripsDao.getTripItemsByTripId(
        tripId,
      );
      expect(itemsBeforeReplace, hasLength(2));

      // === ACT ===
      // Replace with new items
      final newItems = [
        TripItemEntriesCompanion.insert(
          id: 'new-item-1',
          tripId: tripId,
          name: 'New Item 1',
          category: ItemCategory.elettronica,
        ),
        TripItemEntriesCompanion.insert(
          id: 'new-item-2',
          tripId: tripId,
          name: 'New Item 2',
          category: ItemCategory.vestiti,
        ),
        TripItemEntriesCompanion.insert(
          id: 'new-item-3',
          tripId: tripId,
          name: 'New Item 3',
          category: ItemCategory.toiletries,
        ),
      ];

      await database.tripsDao.replaceTripItems(tripId, newItems);

      // === ASSERT ===
      final itemsAfterReplace = await database.tripsDao.getTripItemsByTripId(
        tripId,
      );
      expect(itemsAfterReplace, hasLength(3));

      // Verify old items are gone
      expect(
        itemsAfterReplace.where((item) => item.name.startsWith('Old')),
        isEmpty,
      );

      // Verify new items exist
      final itemNames = itemsAfterReplace.map((item) => item.name).toSet();
      expect(
        itemNames,
        containsAll(['New Item 1', 'New Item 2', 'New Item 3']),
      );

      // Verify categories
      final electronicItem = itemsAfterReplace.firstWhere(
        (item) => item.name == 'New Item 1',
      );
      expect(electronicItem.category, equals(ItemCategory.elettronica));
    });

    test('should update trip item checkbox status', () async {
      // === ARRANGE ===
      final tripId = 'trip-checkbox';

      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          name: 'Checkbox Trip',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final itemId = 'item-checkbox';
      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: itemId,
          tripId: tripId,
          name: 'Item to Check',
          category: ItemCategory.varie,
        ),
      );

      // Verify initial state (unchecked)
      final itemsBefore = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(itemsBefore.first.isChecked, isFalse);

      // === ACT ===
      // Use custom SQL update to update only the isChecked field
      await database.customStatement(
        'UPDATE trip_item_entries SET is_checked = ? WHERE id = ?',
        [1, itemId], // 1 for true, 0 for false
      );

      // === ASSERT ===
      final itemsAfter = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(itemsAfter.first.isChecked, isTrue);
    });
  });

  group('TripsDao - Luggage Associations', () {
    test('should replace all luggage associations for a trip', () async {
      // === ARRANGE ===
      final houseId = 'house-replace-luggages';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Replace Luggages House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Create 4 luggages
      final luggageIds = ['lug-1', 'lug-2', 'lug-3', 'lug-4'];
      for (final lugId in luggageIds) {
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: lugId,
            houseId: houseId,
            name: 'Luggage $lugId',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final tripId = 'trip-replace-luggages';
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          name: 'Replace Luggages Trip',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Link first 2 luggages
      await database.luggagesDao.linkLuggageToTrip(tripId, luggageIds[0]);
      await database.luggagesDao.linkLuggageToTrip(tripId, luggageIds[1]);

      // Verify initial state
      final luggagesBefore = await database.luggagesDao.getLuggagesByTrip(
        tripId,
      );
      expect(luggagesBefore, hasLength(2));

      // === ACT ===
      // Replace with last 2 luggages
      await database.luggagesDao.replaceTripLuggages(tripId, [
        luggageIds[2],
        luggageIds[3],
      ]);

      // === ASSERT ===
      final luggagesAfter = await database.luggagesDao.getLuggagesByTrip(
        tripId,
      );
      expect(luggagesAfter, hasLength(2));

      final linkedIds = luggagesAfter.map((l) => l.id).toSet();
      expect(linkedIds, containsAll([luggageIds[2], luggageIds[3]]));
      expect(linkedIds, isNot(contains(luggageIds[0])));
      expect(linkedIds, isNot(contains(luggageIds[1])));
    });

    test('should unlink a specific luggage from trip', () async {
      // === ARRANGE ===
      final houseId = 'house-unlink';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Unlink House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final luggage1Id = 'lug-unlink-1';
      final luggage2Id = 'lug-unlink-2';

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage1Id,
          houseId: houseId,
          name: 'Luggage 1',
          sizeType: LuggageSize.smallBackpack,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage2Id,
          houseId: houseId,
          name: 'Luggage 2',
          sizeType: LuggageSize.holdBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final tripId = 'trip-unlink';
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          name: 'Unlink Trip',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Link both luggages
      await database.luggagesDao.linkLuggageToTrip(tripId, luggage1Id);
      await database.luggagesDao.linkLuggageToTrip(tripId, luggage2Id);

      // Verify both are linked
      final luggagesBefore = await database.luggagesDao.getLuggagesByTrip(
        tripId,
      );
      expect(luggagesBefore, hasLength(2));

      // === ACT ===
      await database.luggagesDao.unlinkLuggageFromTrip(tripId, luggage1Id);

      // === ASSERT ===
      final luggagesAfter = await database.luggagesDao.getLuggagesByTrip(
        tripId,
      );
      expect(luggagesAfter, hasLength(1));
      expect(luggagesAfter.first.id, equals(luggage2Id));
    });
  });

  group('TripsDao - Optimized Batch Loading', () {
    test(
      'should load all trip items grouped by trip in a single query',
      () async {
        // === ARRANGE ===
        // Create 3 trips
        final trip1Id = 'batch-trip-1';
        final trip2Id = 'batch-trip-2';
        final trip3Id = 'batch-trip-3';

        final now = DateTime.now();

        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: trip1Id,
            name: 'Trip 1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: trip2Id,
            name: 'Trip 2',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: trip3Id,
            name: 'Trip 3',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Add items to each trip
        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'item-1-1',
            tripId: trip1Id,
            name: 'Trip 1 Item 1',
            category: ItemCategory.varie,
          ),
        );

        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'item-1-2',
            tripId: trip1Id,
            name: 'Trip 1 Item 2',
            category: ItemCategory.varie,
          ),
        );

        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'item-2-1',
            tripId: trip2Id,
            name: 'Trip 2 Item 1',
            category: ItemCategory.varie,
          ),
        );

        // Trip 3 has no items

        // === ACT ===
        final groupedItems = await database.tripsDao.getAllTripItemsGrouped();

        // === ASSERT ===
        expect(groupedItems, hasLength(2)); // Only trips 1 and 2 have items

        expect(groupedItems[trip1Id], hasLength(2));
        expect(groupedItems[trip2Id], hasLength(1));
        expect(groupedItems[trip3Id], equals(null));

        // Verify item names
        expect(
          groupedItems[trip1Id]!.map((item) => item.name).toSet(),
          containsAll(['Trip 1 Item 1', 'Trip 1 Item 2']),
        );

        expect(groupedItems[trip2Id]!.first.name, equals('Trip 2 Item 1'));
      },
    );

    test(
      'should load all trip luggages grouped by trip in a single query',
      () async {
        // === ARRANGE ===
        final houseId = 'batch-house';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Batch House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Create luggages
        final lug1Id = 'batch-lug-1';
        final lug2Id = 'batch-lug-2';
        final lug3Id = 'batch-lug-3';

        final now = DateTime.now();

        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: lug1Id,
            houseId: houseId,
            name: 'Batch Luggage 1',
            sizeType: LuggageSize.smallBackpack,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: lug2Id,
            houseId: houseId,
            name: 'Batch Luggage 2',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: lug3Id,
            houseId: houseId,
            name: 'Batch Luggage 3',
            sizeType: LuggageSize.holdBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Create trips
        final trip1Id = 'batch-lug-trip-1';
        final trip2Id = 'batch-lug-trip-2';

        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: trip1Id,
            name: 'Luggage Trip 1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: trip2Id,
            name: 'Luggage Trip 2',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Link luggages
        await database.luggagesDao.linkLuggageToTrip(trip1Id, lug1Id);
        await database.luggagesDao.linkLuggageToTrip(trip1Id, lug2Id);
        await database.luggagesDao.linkLuggageToTrip(trip2Id, lug3Id);

        // === ACT ===
        final groupedLuggages = await database.tripsDao
            .getAllTripLuggagesGrouped();

        // === ASSERT ===
        expect(groupedLuggages, hasLength(2));

        expect(groupedLuggages[trip1Id], hasLength(2));
        expect(groupedLuggages[trip2Id], hasLength(1));

        // Verify luggage details
        final trip1LuggageNames = groupedLuggages[trip1Id]!
            .map((l) => l.name)
            .toSet();
        expect(
          trip1LuggageNames,
          containsAll(['Batch Luggage 1', 'Batch Luggage 2']),
        );

        expect(groupedLuggages[trip2Id]!.first.name, equals('Batch Luggage 3'));
        expect(
          groupedLuggages[trip2Id]!.first.sizeType,
          equals(LuggageSize.holdBaggage),
        );
      },
    );
  });

  group('TripsDao - Duplicate Trip (Deep Copy)', () {
    test(
      'should duplicate trip with all items in atomic transaction',
      () async {
        // === ARRANGE ===
        // Create a house
        final houseId = 'test-house-dup';
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: houseId,
            name: 'Test House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Create original trip
        final originalTripId = 'original-trip-id';
        final originalTrip = TripsCompanion.insert(
          id: originalTripId,
          name: 'Summer 2026',
          description: const Value('Beach vacation'),
          departureDateTime: Value(DateTime(2026, 7, 1)),
          returnDateTime: Value(DateTime(2026, 7, 15)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await database.tripsDao.insertTrip(originalTrip);

        // Add items to original trip
        final tripItems = [
          TripItemEntriesCompanion.insert(
            id: 'item-1',
            tripId: originalTripId,
            name: 'Sunscreen',
            category: ItemCategory.toiletries,
            quantity: const Value(2),
            originHouseId: Value(houseId),
            isChecked: const Value(true),
          ),
          TripItemEntriesCompanion.insert(
            id: 'item-2',
            tripId: originalTripId,
            name: 'T-shirt',
            category: ItemCategory.vestiti,
            quantity: const Value(5),
            originHouseId: Value(houseId),
            isChecked: const Value(false),
          ),
        ];
        await database.tripsDao.insertMultipleTripItems(tripItems);

        // === ACT ===
        final newTripId = 'duplicated-trip-id';
        await database.tripsDao.duplicateTrip(originalTripId, newTripId);

        // === ASSERT ===
        // 1. Verify new trip exists with "(Copia)" suffix
        final duplicatedTrip = await database.tripsDao.getTripById(newTripId);
        expect(duplicatedTrip != null, true);
        expect(duplicatedTrip!.name, 'Summer 2026 (Copia)');
        expect(duplicatedTrip.description, 'Beach vacation');
        expect(duplicatedTrip.departureDateTime, DateTime(2026, 7, 1));
        expect(duplicatedTrip.returnDateTime, DateTime(2026, 7, 15));

        // 2. Verify original trip still exists
        final originalTripCheck = await database.tripsDao.getTripById(
          originalTripId,
        );
        expect(originalTripCheck != null, true);

        // 3. Verify items were copied to new trip
        final duplicatedItems = await database.tripsDao.getTripItemsByTripId(
          newTripId,
        );
        expect(duplicatedItems.length, 2);

        // 4. Verify item data preserved
        final sunscreenCopy = duplicatedItems.firstWhere(
          (i) => i.name == 'Sunscreen',
        );
        expect(sunscreenCopy.category, ItemCategory.toiletries);
        expect(sunscreenCopy.quantity, 2);
        expect(sunscreenCopy.isChecked, false); // ✅ Reset to unchecked
        expect(sunscreenCopy.tripId, newTripId);

        final tshirtCopy = duplicatedItems.firstWhere(
          (i) => i.name == 'T-shirt',
        );
        expect(tshirtCopy.category, ItemCategory.vestiti);
        expect(tshirtCopy.quantity, 5);
        expect(tshirtCopy.isChecked, false); // ✅ Reset to unchecked

        // 5. Verify original items unchanged
        final originalItems = await database.tripsDao.getTripItemsByTripId(
          originalTripId,
        );
        expect(originalItems.length, 2);
        expect(
          originalItems.firstWhere((i) => i.name == 'Sunscreen').isChecked,
          true,
        );
      },
    );

    test('should apply custom nameSuffix when provided (i18n)', () async {
      final houseId = 'house-suffix';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Home',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final originalTripId = 'trip-orig';
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: originalTripId,
          name: 'Summer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.tripsDao.duplicateTrip(
        originalTripId,
        'trip-dup-en',
        nameSuffix: ' (copy)',
      );

      final dup = await database.tripsDao.getTripById('trip-dup-en');
      expect(dup, isNotNull);
      expect(dup!.name, equals('Summer (copy)'));
    });

    test('should throw exception when duplicating non-existent trip', () async {
      // === ACT & ASSERT ===
      expect(
        () => database.tripsDao.duplicateTrip('non-existent-trip', 'new-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle trip with no items', () async {
      // === ARRANGE ===
      final originalTripId = 'empty-trip-id';
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: originalTripId,
          name: 'Empty Trip',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // === ACT ===
      final newTripId = 'duplicated-empty-trip';
      await database.tripsDao.duplicateTrip(originalTripId, newTripId);

      // === ASSERT ===
      final duplicatedTrip = await database.tripsDao.getTripById(newTripId);
      expect(duplicatedTrip != null, true);
      expect(duplicatedTrip!.name, 'Empty Trip (Copia)');

      final duplicatedItems = await database.tripsDao.getTripItemsByTripId(
        newTripId,
      );
      expect(duplicatedItems.length, 0);
    });
  });

  group('TripsDao - Sync Operations', () {
    Future<void> insertTrip(
      String id, {
      SyncStatus status = SyncStatus.pendingCreate,
    }) async {
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          name: 'Trip $id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (status != SyncStatus.pendingCreate) {
        await (database.update(database.trips)..where((t) => t.id.equals(id)))
            .write(TripsCompanion(syncStatus: Value(status)));
      }
    }

    test(
      'getPendingSyncRecords returns only non-synced trips below retry limit',
      () async {
        await insertTrip('pending-1');
        await insertTrip('pending-2', status: SyncStatus.pendingUpdate);
        await insertTrip('synced-1', status: SyncStatus.synced);

        final pending = await database.tripsDao.getPendingSyncRecords();

        expect(pending, hasLength(2));
        final ids = pending.map((t) => t.id).toSet();
        expect(ids, containsAll(['pending-1', 'pending-2']));
        expect(ids, isNot(contains('synced-1')));
      },
    );

    test('getPendingSyncRecords excludes trips exceeding maxRetries', () async {
      await insertTrip('retry-exhausted');
      await (database.update(database.trips)
            ..where((t) => t.id.equals('retry-exhausted')))
          .write(const TripsCompanion(syncRetryCount: Value(5)));

      final pending = await database.tripsDao.getPendingSyncRecords(
        maxRetries: 5,
      );

      expect(pending, isEmpty);
    });

    test(
      'getPendingSyncRecords includes soft-deleted trips (to propagate deletion to server)',
      () async {
        await insertTrip('deleted-pending');
        await database.tripsDao.deleteTrip('deleted-pending');

        final pending = await database.tripsDao.getPendingSyncRecords();
        expect(pending, hasLength(1));
        expect(pending.first.id, equals('deleted-pending'));
        expect(pending.first.isDeleted, isTrue);
      },
    );

    test('markAsSynced resets retry state and sets lastSyncedAt', () async {
      await insertTrip('to-sync');
      // Simulate a prior failed attempt
      await database.tripsDao.incrementSyncRetry('to-sync', 'timeout');

      final serverTime = DateTime(2026, 4, 28, 12, 0);
      final toSync = await database.tripsDao.getTripById('to-sync');
      await database.tripsDao.markAsSynced(
        'to-sync',
        serverTime,
        localUpdatedAt: toSync!.updatedAt,
      );

      final trip = await database.tripsDao.getTripById('to-sync');
      expect(trip, isA<Trip>());
      expect(trip!.syncStatus, equals(SyncStatus.synced));
      expect(trip.syncRetryCount, equals(0));
      expect(trip.lastSyncError, equals(null));
      expect(trip.lastSyncedAt, equals(serverTime));
    });

    test('incrementSyncRetry increments count and records error', () async {
      await insertTrip('retry-me');

      await database.tripsDao.incrementSyncRetry('retry-me', 'network timeout');
      var trip = await database.tripsDao.getTripById('retry-me');
      expect(trip!.syncRetryCount, equals(1));
      expect(trip.lastSyncError, equals('network timeout'));

      await database.tripsDao.incrementSyncRetry('retry-me', 'server 500');
      trip = await database.tripsDao.getTripById('retry-me');
      expect(trip!.syncRetryCount, equals(2));
      expect(trip.lastSyncError, equals('server 500'));
    });

    test('incrementSyncRetry is a no-op for non-existent trip', () async {
      // Should not throw
      await database.tripsDao.incrementSyncRetry('ghost-id', 'error');
    });

    test('new trips default to pendingCreate sync status', () async {
      await insertTrip('fresh');
      final trip = await database.tripsDao.getTripById('fresh');
      expect(trip!.syncStatus, equals(SyncStatus.pendingCreate));
      expect(trip.syncRetryCount, equals(0));
      expect(trip.lastSyncError, equals(null));
      expect(trip.userId, equals(null));
    });

    test('markAsSynced overwrites updatedAt with server timestamp '
        '(post fix #6: server-side updated_at)', () async {
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 't-server-ts',
          name: 'Trip',
          createdAt: DateTime(2026, 5, 1, 7, 0),
          updatedAt: DateTime(2026, 5, 1, 8, 0),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      final clientUpdatedAt = DateTime(2026, 5, 1, 8, 0);
      final serverTs = DateTime(2026, 5, 1, 12, 0);
      await database.tripsDao.markAsSynced(
        't-server-ts',
        serverTs,
        localUpdatedAt: clientUpdatedAt,
      );

      final trip = await database.tripsDao.getTripById('t-server-ts');
      expect(
        trip!.updatedAt,
        equals(serverTs),
        reason:
            'updatedAt deve essere allineato al server timestamp per '
            'rendere immune la LWW al clock drift del client',
      );
      expect(trip.syncStatus, equals(SyncStatus.synced));
      expect(trip.lastSyncedAt, equals(serverTs));
    });

    test('markAsSynced is no-op when updatedAt changed during push '
        '(race condition guard)', () async {
      final originalUpdatedAt = DateTime(2026, 6, 1, 8, 0);
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 't-race',
          name: 'Trip Race',
          createdAt: DateTime(2026, 6, 1, 7, 0),
          updatedAt: originalUpdatedAt,
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      final userEditedAt = DateTime(2026, 6, 1, 9, 0);
      await (database.update(
        database.trips,
      )..where((t) => t.id.equals('t-race'))).write(
        TripsCompanion(
          updatedAt: Value(userEditedAt),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      final serverTs = DateTime(2026, 6, 1, 12, 0);
      await database.tripsDao.markAsSynced(
        't-race',
        serverTs,
        localUpdatedAt: originalUpdatedAt,
      );

      final trip = await database.tripsDao.getTripById('t-race');
      expect(
        trip!.syncStatus,
        equals(SyncStatus.pendingUpdate),
        reason: 'record modificato durante il push deve restare pendingUpdate',
      );
      expect(
        trip.updatedAt,
        equals(userEditedAt),
        reason: "l'edit dell'utente non deve essere sovrascritto",
      );
    });

    test('resetSyncRetries clears retry counter, error and backoff', () async {
      await insertTrip('t-blocked');
      for (var i = 0; i < 5; i++) {
        await database.tripsDao.incrementSyncRetry('t-blocked', 'boom');
      }

      final reset = await database.tripsDao.resetSyncRetries();
      expect(reset, greaterThan(0));

      final trip = await database.tripsDao.getTripById('t-blocked');
      expect(trip!.syncRetryCount, equals(0));
      expect(trip.lastSyncError, isNull);
      expect(trip.nextSyncAttemptAt, isNull);
    });

    test(
      'setTripItemChecked toggles only isChecked, preserves other fields and bumps trip',
      () async {
        await insertTrip('t-toggle');
        // Force trip synced so we can verify the pendingUpdate transition.
        await (database.update(database.trips)
              ..where((t) => t.id.equals('t-toggle')))
            .write(const TripsCompanion(syncStatus: Value(SyncStatus.synced)));

        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'ti-1',
            tripId: 't-toggle',
            name: 'Sweater',
            category: ItemCategory.vestiti,
            quantity: const Value(3),
            originHouseId: const Value('h-origin'),
            isChecked: const Value(false),
          ),
        );

        await database.tripsDao.setTripItemChecked('ti-1', 't-toggle', true);

        final entries = await database.tripsDao.getTripItemsByTripId(
          't-toggle',
        );
        expect(entries, hasLength(1));
        final entry = entries.first;
        expect(entry.isChecked, isTrue, reason: 'isChecked must be toggled');
        expect(entry.name, equals('Sweater'));
        expect(entry.category, equals(ItemCategory.vestiti));
        expect(entry.quantity, equals(3));
        expect(entry.originHouseId, equals('h-origin'));

        final trip = await database.tripsDao.findTripById('t-toggle');
        expect(
          trip!.syncStatus,
          equals(SyncStatus.pendingUpdate),
          reason:
              'bumping trip.updatedAt must mark it pending so sync propagates',
        );
      },
    );

    test('wipeAll physically removes every trip and its snapshots', () async {
      await insertTrip('t-1');
      await insertTrip('t-2', status: SyncStatus.synced);
      // Attach a snapshot item to verify FK cascade also clears entries.
      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: 'ti-wipe',
          tripId: 't-1',
          name: 'Item',
          category: ItemCategory.varie,
        ),
      );

      await database.tripsDao.wipeAll();

      final trips = await database.select(database.trips).get();
      final entries = await database.select(database.tripItemEntries).get();
      expect(trips, isEmpty);
      expect(entries, isEmpty, reason: 'cascade must clear snapshots too');
    });

    test(
      'updateTrip preserves sync metadata when companion omits sync fields',
      () async {
        final originalSyncedAt = DateTime(2026, 5, 1, 8, 0);
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: 't-keep-sync',
            name: 'Original',
            createdAt: DateTime(2026, 5, 1, 7, 0),
            updatedAt: DateTime(2026, 5, 1, 7, 0),
            syncStatus: const Value(SyncStatus.synced),
            syncRetryCount: const Value(3),
            lastSyncedAt: Value(originalSyncedAt),
          ),
        );

        await database.tripsDao.updateTrip(
          TripsCompanion(
            id: const Value('t-keep-sync'),
            name: const Value('Renamed'),
            createdAt: Value(DateTime(2026, 5, 1, 7, 0)),
            updatedAt: Value(DateTime(2026, 5, 1, 10, 0)),
          ),
        );

        final trip = await database.tripsDao.getTripById('t-keep-sync');
        expect(trip!.name, equals('Renamed'));
        expect(trip.lastSyncedAt, equals(originalSyncedAt));
        expect(trip.syncRetryCount, equals(3));
        expect(trip.syncStatus, equals(SyncStatus.pendingUpdate));
      },
    );
  });
}
