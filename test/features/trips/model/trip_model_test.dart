import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';
import 'package:stuff_tracker_2/features/luggages/model/luggage_model.dart';
import 'package:stuff_tracker_2/features/trips/model/trip_model.dart';
import 'package:stuff_tracker_2/shared/model/location_suggestion_model.dart';
import 'package:stuff_tracker_2/shared/model/location_type.dart';

/// Unit tests for TripModel domain logic.
/// 
/// Tests pure domain methods including:
/// - Item count calculations (total, completed, percentage)
/// - Trip status computation based on dates
/// - Luggage volume calculations
/// - Edge cases (empty lists, null values, boundary conditions)
void main() {
  group('TripModel - Item Count Calculations', () {
    test('should correctly count total items (list length)', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-1',
        name: 'Test Trip',
        items: [
          TripItem(
            id: 'item-1',
            name: 'Item 1',
            category: ItemCategory.varie,
            quantity: 1,
          ),
          TripItem(
            id: 'item-2',
            name: 'Item 2',
            category: ItemCategory.varie,
            quantity: 3,
          ),
          TripItem(
            id: 'item-3',
            name: 'Item 3',
            category: ItemCategory.varie,
            quantity: 2,
          ),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final totalCount = trip.totalCount;

      // === ASSERT ===
      // Note: totalCount returns the number of items in the list, not sum of quantities
      expect(totalCount, equals(3), reason: 'Should count 3 items in list');
    });

    test('should correctly count completed items (isChecked = true)', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-2',
        name: 'Test Trip',
        items: [
          TripItem(
            id: 'item-1',
            name: 'Item 1',
            category: ItemCategory.varie,
            quantity: 2,
            isChecked: true, // Checked
          ),
          TripItem(
            id: 'item-2',
            name: 'Item 2',
            category: ItemCategory.varie,
            quantity: 5,
            isChecked: false, // Not checked
          ),
          TripItem(
            id: 'item-3',
            name: 'Item 3',
            category: ItemCategory.varie,
            quantity: 1,
            isChecked: true, // Checked
          ),
          TripItem(
            id: 'item-4',
            name: 'Item 4',
            category: ItemCategory.varie,
            quantity: 3,
            isChecked: false, // Not checked
          ),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final completedCount = trip.completedCount;

      // === ASSERT ===
      // Note: completedCount returns the count of checked items, not sum of quantities
      expect(completedCount, equals(2), reason: 'Should count 2 checked items');
    });

    test('should correctly calculate completion percentage', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-3',
        name: 'Test Trip',
        items: [
          TripItem(id: 'i1', name: 'I1', category: ItemCategory.varie, quantity: 1, isChecked: true),
          TripItem(id: 'i2', name: 'I2', category: ItemCategory.varie, quantity: 1, isChecked: true),
          TripItem(id: 'i3', name: 'I3', category: ItemCategory.varie, quantity: 1, isChecked: false),
          TripItem(id: 'i4', name: 'I4', category: ItemCategory.varie, quantity: 1, isChecked: false),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final percentage = trip.completionPercentage;

      // === ASSERT ===
      expect(percentage, equals(0.5), reason: '2 checked out of 4 total = 50%');
    });

    test('should handle empty items list', () {
      // === ARRANGE ===
      final emptyTrip = TripModel(
        id: 'empty-trip',
        name: 'Empty Trip',
        items: [], // No items
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(emptyTrip.totalCount, equals(0));
      expect(emptyTrip.completedCount, equals(0));
      expect(emptyTrip.completionPercentage, equals(0.0), reason: 'Empty list = 0% by convention');
    });

    test('should handle all items unchecked (0% complete)', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-none-checked',
        name: 'Trip',
        items: [
          TripItem(id: 'i1', name: 'I1', category: ItemCategory.varie, quantity: 1, isChecked: false),
          TripItem(id: 'i2', name: 'I2', category: ItemCategory.varie, quantity: 1, isChecked: false),
          TripItem(id: 'i3', name: 'I3', category: ItemCategory.varie, quantity: 1, isChecked: false),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(trip.totalCount, equals(3));
      expect(trip.completedCount, equals(0));
      expect(trip.completionPercentage, equals(0.0));
    });

    test('should handle all items checked (100% complete)', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-all-checked',
        name: 'Trip',
        items: [
          TripItem(id: 'i1', name: 'I1', category: ItemCategory.varie, quantity: 1, isChecked: true),
          TripItem(id: 'i2', name: 'I2', category: ItemCategory.varie, quantity: 1, isChecked: true),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(trip.totalCount, equals(2));
      expect(trip.completedCount, equals(2));
      expect(trip.completionPercentage, equals(1.0), reason: '2/2 = 100%');
    });
  });

  group('TripModel - Trip Status Computation', () {
    test('should return upcoming status when departure date is in the future', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 10));

      final trip = TripModel(
        id: 'trip-upcoming',
        name: 'Future Trip',
        items: [],
        luggages: [],
        departureDateTime: futureDate,
        returnDateTime: futureDate.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final status = trip.status;

      // === ASSERT ===
      expect(status, equals(TripStatus.upcoming));
      expect(trip.isUpcoming, isTrue);
      expect(trip.isActive, isFalse);
      expect(trip.isCompleted, isFalse);
    });

    test('should return active status when trip is currently ongoing', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 3));
      final futureDate = now.add(const Duration(days: 4));

      final trip = TripModel(
        id: 'trip-active',
        name: 'Active Trip',
        items: [],
        luggages: [],
        departureDateTime: pastDate, // Departed 3 days ago
        returnDateTime: futureDate, // Returns in 4 days
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final status = trip.status;

      // === ASSERT ===
      expect(status, equals(TripStatus.active));
      expect(trip.isActive, isTrue);
      expect(trip.isUpcoming, isFalse);
      expect(trip.isCompleted, isFalse);
    });

    test('should return completed status when return date is in the past', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final pastDeparture = now.subtract(const Duration(days: 14));
      final pastReturn = now.subtract(const Duration(days: 7));

      final trip = TripModel(
        id: 'trip-completed',
        name: 'Completed Trip',
        items: [],
        luggages: [],
        departureDateTime: pastDeparture,
        returnDateTime: pastReturn, // Returned 7 days ago
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final status = trip.status;

      // === ASSERT ===
      expect(status, equals(TripStatus.completed));
      expect(trip.isCompleted, isTrue);
      expect(trip.isActive, isFalse);
      expect(trip.isUpcoming, isFalse);
    });

    test('should return upcoming when departure date is null', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-no-departure',
        name: 'Trip without Departure',
        items: [],
        luggages: [],
        departureDateTime: null, // No departure date set
        returnDateTime: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final status = trip.status;

      // === ASSERT ===
      expect(status, equals(TripStatus.upcoming));
      expect(trip.isUpcoming, isTrue);
    });

    test('should return active when return date is null but departure is past', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final pastDeparture = now.subtract(const Duration(days: 5));

      final trip = TripModel(
        id: 'trip-no-return',
        name: 'Trip without Return',
        items: [],
        luggages: [],
        departureDateTime: pastDeparture,
        returnDateTime: null, // No return date (open-ended trip)
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final status = trip.status;

      // === ASSERT ===
      // Per design: se non c'è data di ritorno, il viaggio è attivo dopo la partenza
      expect(status, equals(TripStatus.active));
      expect(trip.isActive, isTrue);
    });

    test('should handle boundary case when departure is exactly now', () {
      // === ARRANGE ===
      final now = DateTime.now();

      final trip = TripModel(
        id: 'trip-boundary',
        name: 'Trip Starting Now',
        items: [],
        luggages: [],
        departureDateTime: now,
        returnDateTime: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final status = trip.status;

      // === ASSERT ===
      // Should be active (now is NOT before now)
      expect(status, equals(TripStatus.active));
      expect(trip.isActive, isTrue);
    });
  });

  group('TripModel - Luggage Calculations', () {
    test('should correctly count number of luggages', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final trip = TripModel(
        id: 'trip-luggages',
        name: 'Trip with Luggages',
        items: [],
        luggages: [
          LuggageModel(
            id: 'l1',
            houseId: 'h1',
            name: 'Suitcase 1',
            sizeType: LuggageSize.holdBaggage,
            volumeLiters: 60,
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: 'l2',
            houseId: 'h1',
            name: 'Suitcase 2',
            sizeType: LuggageSize.cabinBaggage,
            volumeLiters: 40,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final count = trip.luggageCount;

      // === ASSERT ===
      expect(count, equals(2));
    });

    test('should correctly sum total luggage volume in liters', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final trip = TripModel(
        id: 'trip-volume',
        name: 'Trip',
        items: [],
        luggages: [
          LuggageModel(
            id: 'l1',
            houseId: 'h1',
            name: 'Large Suitcase',
            sizeType: LuggageSize.holdBaggage,
            // Note: volumeLiters field is ignored for standard sizes
            // effectiveVolumeLiters returns approximateVolumeLiters from enum (80)
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: 'l2',
            houseId: 'h1',
            name: 'Cabin Suitcase',
            sizeType: LuggageSize.cabinBaggage,
            // effectiveVolumeLiters = 40 (approximate)
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: 'l3',
            houseId: 'h1',
            name: 'Backpack',
            sizeType: LuggageSize.smallBackpack,
            // effectiveVolumeLiters = 20 (approximate)
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final totalVolume = trip.totalLuggageVolume;

      // === ASSERT ===
      // Business Logic: Standard sizes use approximateVolumeLiters from enum
      expect(totalVolume, equals(140), reason: '80 (holdBaggage) + 40 (cabinBaggage) + 20 (smallBackpack) = 140 liters');
    });

    test('should handle luggage with custom size and explicit volume', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final trip = TripModel(
        id: 'trip-custom-volume',
        name: 'Trip',
        items: [],
        luggages: [
          LuggageModel(
            id: 'l1',
            houseId: 'h1',
            name: 'Cabin Luggage',
            sizeType: LuggageSize.cabinBaggage,
            // Business Logic: volumeLiters is ignored for standard sizes
            // effectiveVolumeLiters = 40 (approximate from enum)
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: 'l2',
            houseId: 'h1',
            name: 'Custom Large Box',
            sizeType: LuggageSize.custom,
            volumeLiters: 120, // Custom explicit volume
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final totalVolume = trip.totalLuggageVolume;

      // === ASSERT ===
      // 40 (cabin approximate) + 120 (custom explicit) = 160
      expect(totalVolume, equals(160), reason: '40 + 120 = 160 liters');
    });

    test('should handle custom luggage with null volume (treated as 0)', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final trip = TripModel(
        id: 'trip-null-volume',
        name: 'Trip',
        items: [],
        luggages: [
          LuggageModel(
            id: 'l1',
            houseId: 'h1',
            name: 'Standard Backpack',
            sizeType: LuggageSize.smallBackpack,
            // effectiveVolumeLiters = 20 (approximate)
            createdAt: now,
            updatedAt: now,
          ),
          LuggageModel(
            id: 'l2',
            houseId: 'h1',
            name: 'Custom Luggage No Volume',
            sizeType: LuggageSize.custom,
            volumeLiters: null, // Custom size but no volume specified
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT ===
      final totalVolume = trip.totalLuggageVolume;

      // === ASSERT ===
      // 20 (smallBackpack) + 0 (custom with null = 0) = 20
      expect(totalVolume, equals(20), reason: '20 + 0 (null treated as 0) = 20');
    });

    test('should handle empty luggages list', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-no-luggages',
        name: 'Trip',
        items: [],
        luggages: [], // Empty
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(trip.luggageCount, equals(0));
      expect(trip.totalLuggageVolume, equals(0));
    });
  });

  group('TripModel - Destination Display Name', () {
    test('should return location display name when location is set', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-location',
        name: 'Trip',
        items: [],
        luggages: [],
        destinationLocation: LocationSuggestionModel(
          placeId: 'place-1',
          displayName: 'Paris, France',
          city: 'Paris',
          country: 'France',
          locationType: LocationType.city,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final displayName = trip.destinationDisplayName;

      // === ASSERT ===
      expect(displayName, equals('Paris, France'));
    });

    test('should return null when no destination location is set', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-no-location',
        name: 'Trip',
        items: [],
        luggages: [],
        destinationLocation: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final displayName = trip.destinationDisplayName;

      // === ASSERT ===
      expect(displayName, equals(null));
    });
  });

  group('TripModel - Factory Methods', () {
    test('should create empty trip with empty() factory', () {
      // === ACT ===
      final emptyTrip = TripModel.empty();

      // === ASSERT ===
      expect(emptyTrip.id, equals(''));
      expect(emptyTrip.name, equals(''));
      expect(emptyTrip.items, isEmpty);
      expect(emptyTrip.luggages, isEmpty);
      expect(emptyTrip.isSaved, isFalse);
      expect(emptyTrip.departureDateTime, equals(null));
      expect(emptyTrip.returnDateTime, equals(null));
      expect(emptyTrip.destinationHouseId, equals(null));
      expect(emptyTrip.destinationLocation, equals(null));
    });
  });

  group('TripModel - Complex Scenarios', () {
    test('should handle trip with items but no luggages', () {
      // === ARRANGE ===
      final trip = TripModel(
        id: 'trip-items-only',
        name: 'Items Only',
        items: [
          TripItem(id: 'i1', name: 'I1', category: ItemCategory.varie, quantity: 1),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(trip.totalCount, equals(1));
      expect(trip.luggageCount, equals(0));
      expect(trip.totalLuggageVolume, equals(0));
    });

    test('should handle trip with luggages but no items', () {
      // === ARRANGE ===
      final now = DateTime.now();
      final trip = TripModel(
        id: 'trip-luggages-only',
        name: 'Luggages Only',
        items: [],
        luggages: [
          LuggageModel(
            id: 'l1',
            houseId: 'h1',
            name: 'Suitcase',
            sizeType: LuggageSize.holdBaggage,
            // Business Logic: volumeLiters ignored for standard sizes
            // effectiveVolumeLiters = 80 (approximate from enum)
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // === ACT & ASSERT ===
      expect(trip.totalCount, equals(0));
      expect(trip.luggageCount, equals(1));
      expect(trip.totalLuggageVolume, equals(80), reason: 'holdBaggage has approximate volume of 80L');
    });

    test('should correctly compute completion for trip with large number of items', () {
      // === ARRANGE ===
      // Create 100 items, 75 checked
      final items = List.generate(
        100,
        (index) => TripItem(
          id: 'item-$index',
          name: 'Item $index',
          category: ItemCategory.varie,
          quantity: 1,
          isChecked: index < 75,
        ),
      );

      final trip = TripModel(
        id: 'trip-large',
        name: 'Large Trip',
        items: items,
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(trip.totalCount, equals(100));
      expect(trip.completedCount, equals(75));
      expect(trip.completionPercentage, equals(0.75), reason: '75/100 = 75%');
    });
  });
}
