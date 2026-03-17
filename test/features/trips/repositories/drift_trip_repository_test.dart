import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:stuff_tracker_2/core/database/database.dart';
import 'package:stuff_tracker_2/core/database/services/database_service.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';
import 'package:stuff_tracker_2/features/luggages/model/luggage_model.dart';
import 'package:stuff_tracker_2/features/trips/model/trip_model.dart' as model;
import 'package:stuff_tracker_2/features/trips/repositories/drift_trip_repository.dart';
import 'package:stuff_tracker_2/shared/model/location_suggestion_model.dart';
import 'package:stuff_tracker_2/shared/model/location_type.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for DriftTripRepository.
/// 
/// Tests the repository layer to ensure:
/// - Correct bidirectional mapping between TripModel (domain) and Drift entities
/// - Complex aggregation of Trip with TripItems (snapshot) and Luggages (M:N)
/// - Transaction integrity for multi-table operations
/// - Foreign key constraints are respected
void main() {
  late AppDatabase database;
  late DatabaseService databaseService;
  late DriftTripRepository repository;

  setUp(() {
    database = createTestDatabase();
    databaseService = DatabaseService(database);
    repository = DriftTripRepository(
      database.tripsDao,
      database.luggagesDao,
      databaseService,
    );
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('DriftTripRepository - Complex Aggregation & Mapping Tests', () {
    test('should correctly map TripModel with items and luggages (addTrip + getTripById)', () async {
      // === ARRANGE ===
      // Step 1: Insert a house (required for FK constraints on luggages and items)
      final houseId = 'test-house-trip-aggregation';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'Test House for Trips',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Step 2: Insert a luggage (to test M:N relationship)
      final luggageId = 'test-luggage-suitcase';
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggageId,
          houseId: houseId,
          name: 'Blue Suitcase',
          sizeType: 'hold_baggage',
          volumeLiters: const Value(60),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Step 3: Create a TripModel with items (snapshot) and luggages
      final now = DateTime.now();
      final departureDate = DateTime(2026, 6, 15, 10, 0);
      final returnDate = DateTime(2026, 6, 22, 18, 0);

      final originalTrip = model.TripModel(
        id: 'trip-aggregation-test',
        name: 'Summer Vacation',
        description: 'Beach trip with family',
        items: [
          model.TripItem(
            id: 'trip-item-1',
            name: 'Sunscreen',
            category: ItemCategory.toiletries,
            quantity: 2,
            originHouseId: houseId,
            isChecked: false,
          ),
          model.TripItem(
            id: 'trip-item-2',
            name: 'Swimsuit',
            category: ItemCategory.vestiti,
            quantity: 1,
            originHouseId: houseId,
            isChecked: true,
          ),
          model.TripItem(
            id: 'trip-item-3',
            name: 'Camera',
            category: ItemCategory.elettronica,
            quantity: 1,
            originHouseId: houseId,
            isChecked: false,
          ),
        ],
        luggages: [
          LuggageModel(
            id: luggageId,
            houseId: houseId,
            name: 'Blue Suitcase',
            sizeType: LuggageSize.holdBaggage,
            volumeLiters: 60,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        departureDateTime: departureDate,
        returnDateTime: returnDate,
        destinationHouseId: null,
        destinationLocation: LocationSuggestionModel(
          placeId: 'place-123',
          displayName: 'Miami Beach, Florida, USA',
          name: 'Miami Beach',
          city: 'Miami Beach',
          state: 'Florida',
          country: 'USA',
          locationType: LocationType.city,
          lat: 25.7907,
          lon: -80.1300,
        ),
        isSaved: true,
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      // Save using repository (Model -> Companions -> DB with transaction)
      await repository.addTrip(originalTrip);

      // Fetch using repository (DB -> Entities -> Model with joins)
      final fetchedTrip = await repository.getTripById(originalTrip.id);

      // === ASSERT ===
      // Verify the fetched object is of type TripModel
      expect(fetchedTrip, isA<model.TripModel>());

      // Verify Trip-level fields match
      expect(fetchedTrip.id, equals(originalTrip.id));
      expect(fetchedTrip.name, equals(originalTrip.name));
      expect(fetchedTrip.description, equals(originalTrip.description));
      expect(fetchedTrip.isSaved, equals(originalTrip.isSaved));
      
      // Verify dates
      expect(
        fetchedTrip.departureDateTime?.difference(departureDate).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        fetchedTrip.returnDateTime?.difference(returnDate).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );

      // CRITICAL: Verify items list is fully populated (snapshot)
      expect(fetchedTrip.items, hasLength(3));

      // Verify each item's properties are preserved
      final sunscreen = fetchedTrip.items.firstWhere((item) => item.name == 'Sunscreen');
      expect(sunscreen.category, equals(ItemCategory.toiletries));
      expect(sunscreen.quantity, equals(2));
      expect(sunscreen.originHouseId, equals(houseId));
      expect(sunscreen.isChecked, equals(false));

      final swimsuit = fetchedTrip.items.firstWhere((item) => item.name == 'Swimsuit');
      expect(swimsuit.category, equals(ItemCategory.vestiti));
      expect(swimsuit.quantity, equals(1));
      expect(swimsuit.isChecked, equals(true));

      final camera = fetchedTrip.items.firstWhere((item) => item.name == 'Camera');
      expect(camera.category, equals(ItemCategory.elettronica));
      expect(camera.quantity, equals(1));

      // CRITICAL: Verify luggages list is fully populated (M:N relationship)
      expect(fetchedTrip.luggages, hasLength(1));
      expect(fetchedTrip.luggages.first, isA<LuggageModel>());
      expect(fetchedTrip.luggages.first.id, equals(luggageId));
      expect(fetchedTrip.luggages.first.name, equals('Blue Suitcase'));
      expect(fetchedTrip.luggages.first.sizeType, equals(LuggageSize.holdBaggage));
      expect(fetchedTrip.luggages.first.volumeLiters, equals(60));

      // Verify destination location is preserved
      expect(fetchedTrip.destinationLocation, isA<LocationSuggestionModel>());
      expect(fetchedTrip.destinationLocation!.displayName, equals('Miami Beach, Florida, USA'));
      expect(fetchedTrip.destinationLocation!.locationType, equals(LocationType.city));
      expect(fetchedTrip.destinationLocation!.lat, equals(25.7907));
      expect(fetchedTrip.destinationLocation!.lon, equals(-80.1300));
    });

    test('should correctly map TripModel with multiple luggages (M:N junction table)', () async {
      // === ARRANGE ===
      final houseId = 'test-house-multiple-luggages';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House with Multiple Luggages',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Insert 3 luggages
      final luggage1Id = 'luggage-cabin';
      final luggage2Id = 'luggage-hold';
      final luggage3Id = 'luggage-backpack';

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage1Id,
          houseId: houseId,
          name: 'Cabin Suitcase',
          sizeType: 'cabin_baggage',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage2Id,
          houseId: houseId,
          name: 'Hold Suitcase',
          sizeType: 'hold_baggage',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage3Id,
          houseId: houseId,
          name: 'Small Backpack',
          sizeType: 'small_backpack',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final tripWith3Luggages = model.TripModel(
        id: 'trip-multiple-luggages',
        name: 'Business Trip',
        items: [],
        luggages: [
          LuggageModel(
            id: luggage1Id,
            houseId: houseId,
            name: 'Cabin Suitcase',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: luggage2Id,
            houseId: houseId,
            name: 'Hold Suitcase',
            sizeType: LuggageSize.holdBaggage,
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: luggage3Id,
            houseId: houseId,
            name: 'Small Backpack',
            sizeType: LuggageSize.smallBackpack,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      await repository.addTrip(tripWith3Luggages);
      final fetchedTrip = await repository.getTripById(tripWith3Luggages.id);

      // === ASSERT ===
      // Verify all 3 luggages are correctly joined and mapped
      expect(fetchedTrip.luggages, hasLength(3));

      final luggageIds = fetchedTrip.luggages.map((l) => l.id).toList();
      expect(luggageIds, containsAll([luggage1Id, luggage2Id, luggage3Id]));

      // Verify each luggage's properties
      final cabinLuggage = fetchedTrip.luggages.firstWhere((l) => l.id == luggage1Id);
      expect(cabinLuggage.name, equals('Cabin Suitcase'));
      expect(cabinLuggage.sizeType, equals(LuggageSize.cabinBaggage));

      final holdLuggage = fetchedTrip.luggages.firstWhere((l) => l.id == luggage2Id);
      expect(holdLuggage.name, equals('Hold Suitcase'));
      expect(holdLuggage.sizeType, equals(LuggageSize.holdBaggage));

      final backpack = fetchedTrip.luggages.firstWhere((l) => l.id == luggage3Id);
      expect(backpack.name, equals('Small Backpack'));
      expect(backpack.sizeType, equals(LuggageSize.smallBackpack));
    });

    test('should correctly map TripModel with destinationHouseId instead of location', () async {
      // === ARRANGE ===
      final originHouseId = 'origin-house';
      final destinationHouseId = 'destination-house';

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: originHouseId,
          name: 'Origin House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: destinationHouseId,
          name: 'Destination House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final tripToHouse = model.TripModel(
        id: 'trip-to-house',
        name: 'Moving Items',
        items: [
          model.TripItem(
            id: 'item-to-move',
            name: 'Laptop',
            category: ItemCategory.elettronica,
            quantity: 1,
            originHouseId: originHouseId,
          ),
        ],
        luggages: [],
        destinationHouseId: destinationHouseId, // Trip to another house
        destinationLocation: null, // No external location
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      await repository.addTrip(tripToHouse);
      final fetchedTrip = await repository.getTripById(tripToHouse.id);

      // === ASSERT ===
      expect(fetchedTrip.destinationHouseId, equals(destinationHouseId));
      expect(fetchedTrip.destinationLocation, equals(null));
      expect(fetchedTrip.items, hasLength(1));
      expect(fetchedTrip.items.first.originHouseId, equals(originHouseId));
    });
  });

  group('DriftTripRepository - CRUD Operations via Repository', () {
    test('should retrieve all trips with correct aggregation', () async {
      // === ARRANGE ===
      final houseId = 'test-house-all-trips';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House for All Trips Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final luggageId = 'luggage-all-trips';
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggageId,
          houseId: houseId,
          name: 'Shared Luggage',
          sizeType: 'cabin_baggage',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();

      // Create 3 trips with different configurations
      final trip1 = model.TripModel(
        id: 'trip-all-1',
        name: 'Trip 1',
        items: [
          model.TripItem(
            id: 'trip1-item1',
            name: 'Item 1',
            category: ItemCategory.varie,
            quantity: 1,
          ),
        ],
        luggages: [],
        createdAt: now,
        updatedAt: now,
      );

      final trip2 = model.TripModel(
        id: 'trip-all-2',
        name: 'Trip 2',
        items: [],
        luggages: [
          LuggageModel(
            id: luggageId,
            houseId: houseId,
            name: 'Shared Luggage',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final trip3 = model.TripModel(
        id: 'trip-all-3',
        name: 'Trip 3',
        items: [
          model.TripItem(
            id: 'trip3-item1',
            name: 'Item A',
            category: ItemCategory.elettronica,
            quantity: 1,
          ),
          model.TripItem(
            id: 'trip3-item2',
            name: 'Item B',
            category: ItemCategory.vestiti,
            quantity: 2,
          ),
        ],
        luggages: [
          LuggageModel(
            id: luggageId,
            houseId: houseId,
            name: 'Shared Luggage',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTrip(trip1);
      await repository.addTrip(trip2);
      await repository.addTrip(trip3);

      // === ACT ===
      final allTrips = await repository.getAllTrips();

      // === ASSERT ===
      expect(allTrips, hasLength(3));

      // Verify each trip has correct items and luggages
      final fetchedTrip1 = allTrips.firstWhere((t) => t.id == 'trip-all-1');
      expect(fetchedTrip1.items, hasLength(1));
      expect(fetchedTrip1.luggages, isEmpty);

      final fetchedTrip2 = allTrips.firstWhere((t) => t.id == 'trip-all-2');
      expect(fetchedTrip2.items, isEmpty);
      expect(fetchedTrip2.luggages, hasLength(1));

      final fetchedTrip3 = allTrips.firstWhere((t) => t.id == 'trip-all-3');
      expect(fetchedTrip3.items, hasLength(2));
      expect(fetchedTrip3.luggages, hasLength(1));
    });

    test('should update trip and replace items and luggages atomically', () async {
      // === ARRANGE ===
      final houseId = 'test-house-update-trip';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House for Update Trip Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final luggage1Id = 'luggage-update-1';
      final luggage2Id = 'luggage-update-2';

      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: luggage1Id,
          houseId: houseId,
          name: 'Luggage 1',
          sizeType: 'cabin_baggage',
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

      final now = DateTime.now();
      final originalTrip = model.TripModel(
        id: 'trip-to-update',
        name: 'Original Trip Name',
        items: [
          model.TripItem(
            id: 'original-item',
            name: 'Original Item',
            category: ItemCategory.varie,
            quantity: 1,
          ),
        ],
        luggages: [
          LuggageModel(
            id: luggage1Id,
            houseId: houseId,
            name: 'Luggage 1',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTrip(originalTrip);

      // === ACT ===
      // Update trip: change name, replace items, replace luggages
      final updatedTrip = originalTrip.copyWith(
        name: 'Updated Trip Name',
        items: [
          model.TripItem(
            id: 'new-item-1',
            name: 'New Item 1',
            category: ItemCategory.elettronica,
            quantity: 2,
          ),
          model.TripItem(
            id: 'new-item-2',
            name: 'New Item 2',
            category: ItemCategory.vestiti,
            quantity: 1,
          ),
        ],
        luggages: [
          LuggageModel(
            id: luggage2Id,
            houseId: houseId,
            name: 'Luggage 2',
            sizeType: LuggageSize.holdBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      await repository.updateTrip(updatedTrip);

      // === ASSERT ===
      final fetchedTrip = await repository.getTripById(originalTrip.id);

      expect(fetchedTrip.name, equals('Updated Trip Name'));

      // Verify items were replaced (not appended)
      expect(fetchedTrip.items, hasLength(2));
      expect(fetchedTrip.items.any((item) => item.id == 'original-item'), isFalse);
      expect(fetchedTrip.items.any((item) => item.id == 'new-item-1'), isTrue);
      expect(fetchedTrip.items.any((item) => item.id == 'new-item-2'), isTrue);

      // Verify luggages were replaced (not appended)
      expect(fetchedTrip.luggages, hasLength(1));
      expect(fetchedTrip.luggages.first.id, equals(luggage2Id));
    });

    test('should delete trip and cascade delete items', () async {
      // === ARRANGE ===
      final houseId = 'test-house-delete-trip';
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: houseId,
          name: 'House for Delete Trip Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final tripToDelete = model.TripModel(
        id: 'trip-to-delete',
        name: 'Trip to Delete',
        items: [
          model.TripItem(
            id: 'item-cascade-delete',
            name: 'Item to Cascade Delete',
            category: ItemCategory.varie,
            quantity: 1,
          ),
        ],
        luggages: [],
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTrip(tripToDelete);

      // Verify trip exists with items
      final tripBeforeDelete = await repository.getTripById(tripToDelete.id);
      expect(tripBeforeDelete, isA<model.TripModel>());
      expect(tripBeforeDelete.items, hasLength(1));

      // === ACT ===
      final deleteResult = await repository.deleteTrip(tripToDelete.id);

      // === ASSERT ===
      expect(deleteResult, isTrue);

      // Attempting to fetch deleted trip should throw
      expect(
        () async => await repository.getTripById(tripToDelete.id),
        throwsA(isA<StateError>()),
      );

      // Verify trip items were cascade deleted (check at DAO level)
      final tripItemsAfterDelete = await database.tripsDao.getTripItemsByTripId(tripToDelete.id);
      expect(tripItemsAfterDelete, isEmpty);
    });
  });

  group('DriftTripRepository - Empty Items and Luggages', () {
    test('should correctly handle trip with no items and no luggages', () async {
      // === ARRANGE ===
      final now = DateTime.now();
      final emptyTrip = model.TripModel(
        id: 'trip-empty',
        name: 'Empty Trip',
        items: [],
        luggages: [],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      await repository.addTrip(emptyTrip);
      final fetchedTrip = await repository.getTripById(emptyTrip.id);

      // === ASSERT ===
      expect(fetchedTrip, isA<model.TripModel>());
      expect(fetchedTrip.items, isEmpty);
      expect(fetchedTrip.luggages, isEmpty);
      expect(fetchedTrip.name, equals('Empty Trip'));
    });
  });
}
