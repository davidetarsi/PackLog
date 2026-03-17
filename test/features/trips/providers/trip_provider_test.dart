import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';
import 'package:stuff_tracker_2/features/trips/model/trip_model.dart';
import 'package:stuff_tracker_2/features/trips/providers/trip_provider.dart';
import 'package:stuff_tracker_2/features/trips/repositories/trip_repository.dart';

/// Mock implementation of TripRepository for testing.
class MockTripRepository extends Mock implements TripRepository {}

/// Unit tests for TripNotifier (Riverpod AsyncNotifier).
/// 
/// Tests the state management layer for trips to ensure:
/// - Correct state transitions (Loading → Data / Error)
/// - CRUD operations refresh state correctly
/// - Error handling propagates to AsyncError state
/// - Repository methods are called with correct parameters
void main() {
  late MockTripRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    // Initialize the mock repository
    mockRepository = MockTripRepository();

    // Register fallback values for any() matchers
    registerFallbackValue(TripModel(
      id: 'fallback',
      name: 'Fallback',
      items: [],
      luggages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    // Create ProviderContainer with mocked repository
    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    // Dispose container to prevent memory leaks between tests
    container.dispose();
  });

  group('TripNotifier - Success Path (AsyncData)', () {
    test('should correctly refresh the state after adding a new trip', () async {
      // === ARRANGE ===
      // Mock repository to return empty list initially, then list with new trip
      final emptyTrips = <TripModel>[];
      
      final newTrip = TripModel(
        id: 'new-trip-1',
        name: 'Summer Vacation',
        description: 'Beach trip',
        items: [
          TripItem(
            id: 'item-1',
            name: 'Sunscreen',
            category: ItemCategory.toiletries,
            quantity: 1,
          ),
        ],
        luggages: [],
        departureDateTime: DateTime(2026, 7, 1),
        returnDateTime: DateTime(2026, 7, 15),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tripsWithNewTrip = [newTrip];

      // First call (build): return empty list
      // Second call (after add): return list with new trip
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => emptyTrips);

      // Mock addTrip to succeed
      when(() => mockRepository.addTrip(any())).thenAnswer((_) async {});

      // === ACT ===
      // Step 1: Await initial build (triggers first getAllTrips call)
      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Verify initial state is empty
      final initialState = container.read(provider);
      expect(initialState.value, isEmpty);

      // Step 2: Update mock to return the new trip on next call
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => tripsWithNewTrip);

      // Step 3: Call addTrip (triggers second getAllTrips call during refresh)
      final notifier = container.read(provider.notifier);
      await notifier.addTrip(newTrip);

      // === ASSERT ===
      // Verify getAllTrips was called twice (initial build + refresh after add)
      verify(() => mockRepository.getAllTrips()).called(2);

      // Verify addTrip was called exactly once with correct trip
      verify(() => mockRepository.addTrip(newTrip)).called(1);

      // Verify final state contains the new trip
      final finalState = container.read(provider);
      expect(finalState, isA<AsyncData<List<TripModel>>>());
      expect(finalState.value, hasLength(1));
      expect(finalState.value!.first.id, equals('new-trip-1'));
      expect(finalState.value!.first.name, equals('Summer Vacation'));
      expect(finalState.value!.first.items, hasLength(1));
    });

    test('should successfully update an existing trip and refresh state', () async {
      // === ARRANGE ===
      final originalTrip = TripModel(
        id: 'trip-to-update',
        name: 'Original Name',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedTrip = originalTrip.copyWith(
        name: 'Updated Name',
        description: 'Updated description',
      );

      // Mock initial state
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [originalTrip]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Mock updateTrip and subsequent refresh
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [updatedTrip]);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.updateTrip(updatedTrip);

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value, hasLength(1));
      expect(finalState.value!.first.name, equals('Updated Name'));
      expect(finalState.value!.first.description, equals('Updated description'));

      verify(() => mockRepository.updateTrip(updatedTrip)).called(1);
      verify(() => mockRepository.getAllTrips()).called(2); // Initial + refresh
    });

    test('should successfully delete a trip and refresh state', () async {
      // === ARRANGE ===
      final trip1 = TripModel(
        id: 'trip-1',
        name: 'Trip 1',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final trip2 = TripModel(
        id: 'trip-to-delete',
        name: 'Trip to Delete',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Mock initial state with 2 trips
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [trip1, trip2]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Mock deleteTrip and refresh (trip2 removed)
      when(() => mockRepository.deleteTrip(any())).thenAnswer((_) async => true);
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [trip1]);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.deleteTrip(trip2.id);

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value, hasLength(1));
      expect(finalState.value!.any((t) => t.id == 'trip-to-delete'), isFalse);
      expect(finalState.value!.first.id, equals('trip-1'));

      verify(() => mockRepository.deleteTrip(trip2.id)).called(1);
    });

    test('should toggle item check status and refresh state', () async {
      // === ARRANGE ===
      final tripWithItems = TripModel(
        id: 'trip-with-items',
        name: 'Trip',
        items: [
          TripItem(
            id: 'item-1',
            name: 'Item 1',
            category: ItemCategory.varie,
            quantity: 1,
            isChecked: false,
          ),
          TripItem(
            id: 'item-2',
            name: 'Item 2',
            category: ItemCategory.varie,
            quantity: 1,
            isChecked: false,
          ),
        ],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [tripWithItems]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Mock updateTrip and refresh with toggled item
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
      
      final tripWithToggledItem = tripWithItems.copyWith(
        items: [
          tripWithItems.items[0].copyWith(isChecked: true), // Toggled
          tripWithItems.items[1],
        ],
      );

      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [tripWithToggledItem]);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.toggleItemCheck('trip-with-items', 'item-1');

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value, hasLength(1));
      
      final trip = finalState.value!.first;
      final toggledItem = trip.items.firstWhere((i) => i.id == 'item-1');
      expect(toggledItem.isChecked, isTrue);

      verify(() => mockRepository.updateTrip(any())).called(1);
    });

    test('should toggle saved status and refresh state', () async {
      // === ARRANGE ===
      final tripNotSaved = TripModel(
        id: 'trip-saved-test',
        name: 'Trip',
        items: [],
        luggages: [],
        isSaved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [tripNotSaved]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
      
      final tripSaved = tripNotSaved.copyWith(isSaved: true);
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [tripSaved]);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.toggleSaved('trip-saved-test');

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value!.first.isSaved, isTrue);

      verify(() => mockRepository.updateTrip(any())).called(1);
    });
  });

  group('TripNotifier - Failure Path (AsyncError)', () {
    test('should transition to AsyncError when repository throws during initial fetch', () async {
      // === ARRANGE ===
      final testException = Exception('Failed to load trips');

      when(() => mockRepository.getAllTrips()).thenThrow(testException);

      // === ACT ===
      final provider = tripNotifierProvider;
      
      try {
        await container.read(provider.future);
        fail('Should have thrown an exception');
      } catch (e) {
        // Expected to throw
      }

      // === ASSERT ===
      final state = container.read(provider);
      expect(state, isA<AsyncError<List<TripModel>>>());
      expect(state.error, equals(testException));
      expect(state.hasError, isTrue);

      verify(() => mockRepository.getAllTrips()).called(1);
    });

    test('should transition to AsyncError when addTrip throws an exception', () async {
      // === ARRANGE ===
      final initialTrips = <TripModel>[];
      
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => initialTrips);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      final newTrip = TripModel(
        id: 'new-trip',
        name: 'New Trip',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final addException = Exception('Failed to add trip');
      when(() => mockRepository.addTrip(any())).thenThrow(addException);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.addTrip(newTrip);

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState, isA<AsyncError<List<TripModel>>>());
      expect(finalState.error, equals(addException));

      verify(() => mockRepository.addTrip(newTrip)).called(1);
      verify(() => mockRepository.getAllTrips()).called(1); // Only initial, no refresh after error
    });

    test('should transition to AsyncError when updateTrip throws an exception', () async {
      // === ARRANGE ===
      final existingTrip = TripModel(
        id: 'trip-1',
        name: 'Trip',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [existingTrip]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      final updatedTrip = existingTrip.copyWith(name: 'Updated');
      final updateException = Exception('Update failed');
      when(() => mockRepository.updateTrip(any())).thenThrow(updateException);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.updateTrip(updatedTrip);

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState, isA<AsyncError<List<TripModel>>>());
      expect(finalState.error, equals(updateException));

      verify(() => mockRepository.updateTrip(updatedTrip)).called(1);
    });

    test('should transition to AsyncError when deleteTrip throws an exception', () async {
      // === ARRANGE ===
      final existingTrip = TripModel(
        id: 'trip-to-delete',
        name: 'Trip',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => [existingTrip]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      final deleteException = Exception('Delete failed');
      when(() => mockRepository.deleteTrip(any())).thenThrow(deleteException);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.deleteTrip(existingTrip.id);

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState, isA<AsyncError<List<TripModel>>>());
      expect(finalState.error, equals(deleteException));

      verify(() => mockRepository.deleteTrip(existingTrip.id)).called(1);
    });
  });

  group('TripNotifier - Refresh Functionality', () {
    test('should manually refresh state when refresh() is called', () async {
      // === ARRANGE ===
      final initialTrips = [
        TripModel(
          id: 'trip-1',
          name: 'Trip 1',
          items: [],
          luggages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final refreshedTrips = [
        TripModel(
          id: 'trip-1',
          name: 'Trip 1',
          items: [],
          luggages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TripModel(
          id: 'trip-2',
          name: 'Trip 2',
          items: [],
          luggages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => initialTrips);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Update mock for refresh
      when(() => mockRepository.getAllTrips())
          .thenAnswer((_) async => refreshedTrips);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.refresh();

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value, hasLength(2));

      verify(() => mockRepository.getAllTrips()).called(2); // Initial + refresh
    });
  });
}
