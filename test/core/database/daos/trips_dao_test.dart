import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:stuff_tracker_2/core/database/database.dart';
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
    test('should insert a trip with snapshot items and luggage links within a transaction', () async {
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
        sizeType: 'hold_baggage',
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
        sizeType: 'small_backpack',
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
          category: 'toiletries',
          quantity: Value(2),
          originHouseId: Value(houseId),
        ),
        TripItemEntriesCompanion.insert(
          id: 'trip-item-2',
          tripId: tripId,
          name: 'Beach Towel',
          category: 'vestiti',
          quantity: Value(1),
          originHouseId: Value(houseId),
        ),
        TripItemEntriesCompanion.insert(
          id: 'trip-item-3',
          tripId: tripId,
          name: 'Sunglasses',
          category: 'accessori',
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
      final retrievedItems = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(retrievedItems, hasLength(3));
      
      // Verify all items have correct tripId foreign key
      for (final item in retrievedItems) {
        expect(item.tripId, equals(tripId));
      }
      
      // Verify specific item details
      final sunscreenItem = retrievedItems.firstWhere((item) => item.name == 'Sunscreen');
      expect(sunscreenItem.category, equals('toiletries'));
      expect(sunscreenItem.quantity, equals(2));
      expect(sunscreenItem.originHouseId, equals(houseId));
      expect(sunscreenItem.isChecked, isFalse); // Default value
      
      final towelItem = retrievedItems.firstWhere((item) => item.name == 'Beach Towel');
      expect(towelItem.quantity, equals(1));
      
      final sunglassesItem = retrievedItems.firstWhere((item) => item.name == 'Sunglasses');
      expect(sunglassesItem.category, equals('accessori'));
      
      // Verify luggage associations via junction table
      final retrievedLuggages = await database.luggagesDao.getLuggagesByTrip(tripId);
      expect(retrievedLuggages, hasLength(2));
      
      // Verify luggage IDs are correct
      final retrievedLuggageIds = retrievedLuggages.map((l) => l.id).toSet();
      expect(retrievedLuggageIds, containsAll([luggageId, luggage2Id]));
      
      // Verify luggage details
      final suitcase = retrievedLuggages.firstWhere((l) => l.name == 'Test Suitcase');
      expect(suitcase.sizeType, equals('hold_baggage'));
      expect(suitcase.houseId, equals(houseId));
      
      final backpack = retrievedLuggages.firstWhere((l) => l.name == 'Test Backpack');
      expect(backpack.sizeType, equals('small_backpack'));
    });

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
        category: 'varie',
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

    test('should enforce foreign key constraints when inserting trip items', () async {
      // === ARRANGE ===
      // DO NOT create a trip - this will violate foreign key constraint
      final nonExistentTripId = 'non-existent-trip';
      
      final tripItem = TripItemEntriesCompanion.insert(
        id: 'orphan-item',
        tripId: nonExistentTripId, // This tripId does not exist
        name: 'Orphan Item',
        category: 'varie',
      );

      // === ACT & ASSERT ===
      // Attempt to insert item with invalid foreign key
      // Should fail because PRAGMA foreign_keys = ON
      expect(
        () async => await database.tripsDao.insertTripItem(tripItem),
        throwsA(isA<Exception>()),
      );
      
      // Verify item was NOT inserted
      final items = await database.tripsDao.getTripItemsByTripId(nonExistentTripId);
      expect(items, isEmpty);
    });

    test('should enforce composite primary key constraint on trip-luggage junction table', () async {
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
          sizeType: 'cabin_baggage',
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
        () async => await database.luggagesDao.linkLuggageToTrip(tripId, luggageId),
        throwsA(isA<Exception>()),
      );
      
      // Verify only one entry exists
      final luggages = await database.luggagesDao.getLuggagesByTrip(tripId);
      expect(luggages, hasLength(1));
    });
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
          category: 'varie',
        ),
      );
      
      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: 'item-to-delete-2',
          tripId: tripId,
          name: 'Item 2',
          category: 'varie',
        ),
      );
      
      // Verify items exist before deletion
      final itemsBeforeDelete = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(itemsBeforeDelete, hasLength(2));

      // === ACT ===
      final deleteResult = await database.tripsDao.deleteTrip(tripId);

      // === ASSERT ===
      expect(deleteResult, equals(1)); // 1 row deleted
      
      // Verify trip is deleted
      final tripAfterDelete = await database.tripsDao.getTripById(tripId);
      expect(tripAfterDelete, equals(null));
      
      // Verify items are cascade deleted (ON DELETE CASCADE)
      final itemsAfterDelete = await database.tripsDao.getTripItemsByTripId(tripId);
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
          category: 'varie',
        ),
        TripItemEntriesCompanion.insert(
          id: 'initial-item-2',
          tripId: tripId,
          name: 'Old Item 2',
          category: 'varie',
        ),
      ];
      
      await database.tripsDao.insertMultipleTripItems(initialItems);
      
      // Verify initial state
      final itemsBeforeReplace = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(itemsBeforeReplace, hasLength(2));

      // === ACT ===
      // Replace with new items
      final newItems = [
        TripItemEntriesCompanion.insert(
          id: 'new-item-1',
          tripId: tripId,
          name: 'New Item 1',
          category: 'elettronica',
        ),
        TripItemEntriesCompanion.insert(
          id: 'new-item-2',
          tripId: tripId,
          name: 'New Item 2',
          category: 'vestiti',
        ),
        TripItemEntriesCompanion.insert(
          id: 'new-item-3',
          tripId: tripId,
          name: 'New Item 3',
          category: 'toiletries',
        ),
      ];
      
      await database.tripsDao.replaceTripItems(tripId, newItems);

      // === ASSERT ===
      final itemsAfterReplace = await database.tripsDao.getTripItemsByTripId(tripId);
      expect(itemsAfterReplace, hasLength(3));
      
      // Verify old items are gone
      expect(
        itemsAfterReplace.where((item) => item.name.startsWith('Old')),
        isEmpty,
      );
      
      // Verify new items exist
      final itemNames = itemsAfterReplace.map((item) => item.name).toSet();
      expect(itemNames, containsAll(['New Item 1', 'New Item 2', 'New Item 3']));
      
      // Verify categories
      final electronicItem = itemsAfterReplace.firstWhere((item) => item.name == 'New Item 1');
      expect(electronicItem.category, equals('elettronica'));
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
          category: 'varie',
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
            sizeType: 'cabin_baggage',
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
      final luggagesBefore = await database.luggagesDao.getLuggagesByTrip(tripId);
      expect(luggagesBefore, hasLength(2));

      // === ACT ===
      // Replace with last 2 luggages
      await database.luggagesDao.replaceTripLuggages(
        tripId,
        [luggageIds[2], luggageIds[3]],
      );

      // === ASSERT ===
      final luggagesAfter = await database.luggagesDao.getLuggagesByTrip(tripId);
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
          sizeType: 'small_backpack',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage2Id,
          houseId: houseId,
          name: 'Luggage 2',
          sizeType: 'hold_baggage',
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
      final luggagesBefore = await database.luggagesDao.getLuggagesByTrip(tripId);
      expect(luggagesBefore, hasLength(2));

      // === ACT ===
      await database.luggagesDao.unlinkLuggageFromTrip(tripId, luggage1Id);

      // === ASSERT ===
      final luggagesAfter = await database.luggagesDao.getLuggagesByTrip(tripId);
      expect(luggagesAfter, hasLength(1));
      expect(luggagesAfter.first.id, equals(luggage2Id));
    });
  });

  group('TripsDao - Optimized Batch Loading', () {
    test('should load all trip items grouped by trip in a single query', () async {
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
          category: 'varie',
        ),
      );
      
      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: 'item-1-2',
          tripId: trip1Id,
          name: 'Trip 1 Item 2',
          category: 'varie',
        ),
      );
      
      await database.tripsDao.insertTripItem(
        TripItemEntriesCompanion.insert(
          id: 'item-2-1',
          tripId: trip2Id,
          name: 'Trip 2 Item 1',
          category: 'varie',
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
    });

    test('should load all trip luggages grouped by trip in a single query', () async {
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
          sizeType: 'small_backpack',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: lug2Id,
          houseId: houseId,
          name: 'Batch Luggage 2',
          sizeType: 'cabin_baggage',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: lug3Id,
          houseId: houseId,
          name: 'Batch Luggage 3',
          sizeType: 'hold_baggage',
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
      final groupedLuggages = await database.tripsDao.getAllTripLuggagesGrouped();

      // === ASSERT ===
      expect(groupedLuggages, hasLength(2));
      
      expect(groupedLuggages[trip1Id], hasLength(2));
      expect(groupedLuggages[trip2Id], hasLength(1));
      
      // Verify luggage details
      final trip1LuggageNames = groupedLuggages[trip1Id]!.map((l) => l.name).toSet();
      expect(trip1LuggageNames, containsAll(['Batch Luggage 1', 'Batch Luggage 2']));
      
      expect(groupedLuggages[trip2Id]!.first.name, equals('Batch Luggage 3'));
      expect(groupedLuggages[trip2Id]!.first.sizeType, equals('hold_baggage'));
    });
  });
}
