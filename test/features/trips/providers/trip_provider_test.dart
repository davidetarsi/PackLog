import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/consent/consent_provider.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/database/daos/suitcase_edits_dao.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/suitcase_edit.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/suitcase_edits_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/ai_suitcase_adoption.dart';

import '../../../helpers/mock_suitcase_edits.dart';
import '../../../helpers/test_database_setup.dart';

/// Mock implementation of TripRepository for testing.
class MockTripRepository extends Mock implements TripRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// Unit tests for TripNotifier (Riverpod AsyncNotifier).
///
/// Tests the state management layer for trips to ensure:
/// - Correct state transitions (Loading → Data / Error)
/// - CRUD operations refresh state correctly
/// - Error handling propagates to AsyncError state
/// - Repository methods are called with correct parameters
void main() {
  late MockTripRepository mockRepository;
  late MockCoreAnalyticsService mockAnalytics;
  late ProviderContainer container;

  setUp(() {
    // Initialize the mock repository
    mockRepository = MockTripRepository();

    // Register fallback values for any() matchers
    registerFallbackValue(
      TripModel(
        id: 'fallback',
        name: 'Fallback',
        items: [],
        luggages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    mockAnalytics = MockCoreAnalyticsService();
    when(
      () => mockAnalytics.trackTripCreated(
        tripId: any(named: 'tripId'),
        totalTrips: any(named: 'totalTrips'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAnalytics.trackItemsAddedToTrip(
        tripId: any(named: 'tripId'),
        count: any(named: 'count'),
      ),
    ).thenAnswer((_) async {});

    final mockSync = MockSyncOrchestrator();
    when(() => mockSync.requestSync()).thenReturn(null);

    final mockItemRepo = MockItemRepository();
    when(
      () => mockItemRepo.moveItemsToHouse(any(), any(), any()),
    ).thenAnswer((_) async {});

    // Create ProviderContainer with mocked repository
    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(mockRepository),
        coreAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
        syncOrchestratorProvider.overrideWithValue(mockSync),
        itemRepositoryProvider.overrideWithValue(mockItemRepo),
        suitcaseEditsDaoProvider.overrideWithValue(noopSuitcaseEditsDao()),
      ],
    );
  });

  void verifyNoPackingEvents() {
    verifyNever(
      () => mockAnalytics.trackPackingStarted(
        tripId: any(named: 'tripId'),
        totalItems: any(named: 'totalItems'),
        daysToDeparture: any(named: 'daysToDeparture'),
      ),
    );
    verifyNever(
      () => mockAnalytics.trackPackingProgress(
        tripId: any(named: 'tripId'),
        threshold: any(named: 'threshold'),
        daysToDeparture: any(named: 'daysToDeparture'),
      ),
    );
    verifyNever(
      () => mockAnalytics.trackPackingCompleted(
        tripId: any(named: 'tripId'),
        totalItems: any(named: 'totalItems'),
        daysToDeparture: any(named: 'daysToDeparture'),
      ),
    );
  }

  tearDown(() {
    // Dispose container to prevent memory leaks between tests
    container.dispose();
  });

  group('TripNotifier - Success Path (AsyncData)', () {
    test('serializza le modifiche allo stesso viaggio tra chiamanti', () async {
      when(() => mockRepository.getAllTrips()).thenAnswer((_) async => []);
      await container.read(tripNotifierProvider.future);
      final notifier = container.read(tripNotifierProvider.notifier);
      final gate = Completer<void>();
      final order = <String>[];

      final first = notifier.serializeEdit('t1', () async {
        order.add('prima-inizio');
        await gate.future;
        order.add('prima-fine');
      });
      final second = notifier.serializeEdit('t1', () async {
        order.add('seconda');
      });
      await Future<void>.delayed(Duration.zero);

      expect(order, ['prima-inizio']);
      gate.complete();
      await Future.wait([first, second]);
      expect(order, ['prima-inizio', 'prima-fine', 'seconda']);
    });

    test('un errore non impedisce la modifica successiva', () async {
      when(() => mockRepository.getAllTrips()).thenAnswer((_) async => []);
      await container.read(tripNotifierProvider.future);
      final notifier = container.read(tripNotifierProvider.notifier);
      final failure = Exception('edit failed');
      var nextRan = false;

      final failed = notifier.serializeEdit('t1', () async => throw failure);
      final next = notifier.serializeEdit('t1', () async {
        nextRan = true;
      });

      await expectLater(failed, throwsA(same(failure)));
      await next;
      expect(nextRan, isTrue);
    });

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
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => emptyTrips);

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
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => tripsWithNewTrip);

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

    test(
      'should successfully update an existing trip and refresh state',
      () async {
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
        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [originalTrip]);

        final provider = tripNotifierProvider;
        await container.read(provider.future);

        // Mock updateTrip and subsequent refresh
        when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [updatedTrip]);

        // === ACT ===
        final notifier = container.read(provider.notifier);
        await notifier.updateTrip(updatedTrip);

        // === ASSERT ===
        final finalState = container.read(provider);
        expect(finalState.value, hasLength(1));
        expect(finalState.value!.first.name, equals('Updated Name'));
        expect(
          finalState.value!.first.description,
          equals('Updated description'),
        );

        verify(() => mockRepository.updateTrip(updatedTrip)).called(1);
        verify(
          () => mockRepository.getAllTrips(),
        ).called(2); // Initial + refresh
      },
    );

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
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [trip1, trip2]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Mock deleteTrip and refresh (trip2 removed)
      when(
        () => mockRepository.deleteTrip(any()),
      ).thenAnswer((_) async => true);
      when(() => mockRepository.getAllTrips()).thenAnswer((_) async => [trip1]);

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

      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [tripWithItems]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      when(
        () => mockRepository.setTripItemChecked(any(), any(), any()),
      ).thenAnswer((_) async {});

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.toggleItemCheck('trip-with-items', 'item-1');

      // === ASSERT ===
      // Optimistic state update senza reload completo: la lista in memoria
      // riflette già il toggle.
      final finalState = container.read(provider);
      expect(finalState.value, hasLength(1));
      final trip = finalState.value!.first;
      final toggledItem = trip.items.firstWhere((i) => i.id == 'item-1');
      expect(toggledItem.isChecked, isTrue);

      verify(
        () => mockRepository.setTripItemChecked(
          'trip-with-items',
          'item-1',
          true,
        ),
      ).called(1);
      verifyNever(() => mockRepository.updateTrip(any()));
      // getAllTrips chiamato solo una volta nel build iniziale, non dopo
      // il toggle (no reload completo).
      verify(() => mockRepository.getAllTrips()).called(1);
    });

    group('funnel della preparazione valigia', () {
      TripModel tripWith({required int total, required int checked}) =>
          TripModel(
            id: 'trip-packing',
            name: 'Trip',
            items: List.generate(
              total,
              (i) => TripItem(
                id: 'item-$i',
                name: 'Item $i',
                category: ItemCategory.varie,
                quantity: 1,
                isChecked: i < checked,
              ),
            ),
            luggages: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      test('la prima spunta emette packing_started', () async {
        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [tripWith(total: 4, checked: 0)]);
        when(
          () => mockRepository.setTripItemChecked(any(), any(), any()),
        ).thenAnswer((_) async {});

        await container.read(tripNotifierProvider.future);
        await container
            .read(tripNotifierProvider.notifier)
            .toggleItemCheck('trip-packing', 'item-0');

        verify(
          () => mockAnalytics.trackPackingStarted(
            tripId: 'trip-packing',
            totalItems: any(named: 'totalItems'),
            daysToDeparture: any(named: 'daysToDeparture'),
          ),
        ).called(1);
      });

      test("l'ultima spunta emette packing_completed", () async {
        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [tripWith(total: 2, checked: 1)]);
        when(
          () => mockRepository.setTripItemChecked(any(), any(), any()),
        ).thenAnswer((_) async {});

        await container.read(tripNotifierProvider.future);
        await container
            .read(tripNotifierProvider.notifier)
            .toggleItemCheck('trip-packing', 'item-1');

        verify(
          () => mockAnalytics.trackPackingCompleted(
            tripId: 'trip-packing',
            totalItems: 2,
            daysToDeparture: any(named: 'daysToDeparture'),
          ),
        ).called(1);
      });

      test('despuntare non emette nulla', () async {
        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [tripWith(total: 4, checked: 2)]);
        when(
          () => mockRepository.setTripItemChecked(any(), any(), any()),
        ).thenAnswer((_) async {});

        await container.read(tripNotifierProvider.future);
        await container
            .read(tripNotifierProvider.notifier)
            .toggleItemCheck('trip-packing', 'item-0');

        verifyNoPackingEvents();
      });

      // Misuriamo fatti, non intenzioni: se il salvataggio fallisce non deve
      // restare traccia di una spunta che non è avvenuta.
      test('nessun evento se la persistenza fallisce', () async {
        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [tripWith(total: 4, checked: 0)]);
        when(
          () => mockRepository.setTripItemChecked(any(), any(), any()),
        ).thenThrow(Exception('db down'));

        await container.read(tripNotifierProvider.future);
        await expectLater(
          container
              .read(tripNotifierProvider.notifier)
              .toggleItemCheck('trip-packing', 'item-0'),
          throwsA(isA<Exception>()),
        );

        verifyNoPackingEvents();
      });
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

      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [tripNotSaved]);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      final tripSaved = tripNotSaved.copyWith(isSaved: true);
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [tripSaved]);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.toggleSaved('trip-saved-test');

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value!.first.isSaved, isTrue);

      verify(() => mockRepository.updateTrip(any())).called(1);
    });
  });

  group('TripNotifier - Failure Path', () {
    test(
      'should transition to AsyncError when repository throws during initial fetch',
      () async {
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
      },
    );

    test(
      'should rethrow and preserve AsyncData when addTrip throws an exception',
      () async {
        // === ARRANGE ===
        final initialTrips = <TripModel>[];

        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => initialTrips);

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

        // === ACT + ASSERT ===
        // Contract: rethrowOnly=true — notifier rethrows so ErrorRetryDialog
        // sees the failure; state is restored to previous AsyncData
        // (no AsyncError flash — list remains visible and intact).
        final notifier = container.read(provider.notifier);
        await expectLater(
          notifier.addTrip(newTrip),
          throwsA(equals(addException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncData<List<TripModel>>>());

        verify(() => mockRepository.addTrip(newTrip)).called(1);
        verify(
          () => mockRepository.getAllTrips(),
        ).called(1); // Only initial, no refresh after error
      },
    );

    test(
      'should rethrow and preserve AsyncData when updateTrip throws an exception',
      () async {
        // === ARRANGE ===
        final existingTrip = TripModel(
          id: 'trip-1',
          name: 'Trip',
          items: [],
          luggages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [existingTrip]);

        final provider = tripNotifierProvider;
        await container.read(provider.future);

        final updatedTrip = existingTrip.copyWith(name: 'Updated');
        final updateException = Exception('Update failed');
        when(() => mockRepository.updateTrip(any())).thenThrow(updateException);

        // === ACT + ASSERT ===
        // Contract: rethrowOnly=true — state preserved as AsyncData.
        final notifier = container.read(provider.notifier);
        await expectLater(
          notifier.updateTrip(updatedTrip),
          throwsA(equals(updateException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncData<List<TripModel>>>());

        verify(() => mockRepository.updateTrip(updatedTrip)).called(1);
      },
    );

    test(
      'should rethrow and preserve AsyncData when deleteTrip throws an exception',
      () async {
        // === ARRANGE ===
        final existingTrip = TripModel(
          id: 'trip-to-delete',
          name: 'Trip',
          items: [],
          luggages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [existingTrip]);

        final provider = tripNotifierProvider;
        await container.read(provider.future);

        final deleteException = Exception('Delete failed');
        when(() => mockRepository.deleteTrip(any())).thenThrow(deleteException);

        // === ACT + ASSERT ===
        // Contract: rethrowOnly=true — state preserved as AsyncData.
        final notifier = container.read(provider.notifier);
        await expectLater(
          notifier.deleteTrip(existingTrip.id),
          throwsA(equals(deleteException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncData<List<TripModel>>>());

        verify(() => mockRepository.deleteTrip(existingTrip.id)).called(1);
      },
    );
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

      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => initialTrips);

      final provider = tripNotifierProvider;
      await container.read(provider.future);

      // Update mock for refresh
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => refreshedTrips);

      // === ACT ===
      final notifier = container.read(provider.notifier);
      await notifier.refresh();

      // === ASSERT ===
      final finalState = container.read(provider);
      expect(finalState.value, hasLength(2));

      verify(() => mockRepository.getAllTrips()).called(2); // Initial + refresh
    });
  });

  group('TripNotifier - addItemsToTrip', () {
    test(
      'calls repository.addItemsToTrip and refreshes state, tracking analytics',
      () async {
        final existingTrip = TripModel(
          id: 'trip-1',
          name: 'Existing Trip',
          items: const [],
          luggages: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final newItem = TripItem(
          id: 'item-1',
          name: 'Sunglasses',
          category: ItemCategory.varie,
          quantity: 1,
          originHouseId: 'house-1',
        );

        when(
          () => mockRepository.getAllTrips(),
        ).thenAnswer((_) async => [existingTrip]);
        when(
          () => mockRepository.addItemsToTrip('trip-1', [newItem]),
        ).thenAnswer((_) async {});

        // Prime the notifier's initial state.
        await container.read(tripNotifierProvider.future);

        await container.read(tripNotifierProvider.notifier).addItemsToTrip(
          'trip-1',
          [newItem],
        );

        verify(
          () => mockRepository.addItemsToTrip('trip-1', [newItem]),
        ).called(1);
        verify(
          () => mockAnalytics.trackItemsAddedToTrip(tripId: 'trip-1', count: 1),
        ).called(1);
      },
    );
  });

  group('TripNotifier - eventi della valigia AI', () {
    const reason = AiReason(code: 'base', label: 'Base', sentence: 'Serve.');

    TripItem packed(String id) => TripItem(
      id: id,
      name: 'capo $id',
      category: ItemCategory.vestiti,
      quantity: 1,
    );

    AiPackingResult result(DateTime generatedAt) => AiPackingResult(
      generatedAt: generatedAt,
      houseId: 'h1',
      proposal: const [
        AiPackedItem(itemId: 'A', quantity: 1, reason: reason),
        AiPackedItem(itemId: 'B', quantity: 1, reason: reason),
      ],
      warnings: const [
        AiWarning(
          id: 'w1',
          code: 'rain_gear',
          level: AiWarningLevel.important,
          title: 'Pioggia',
          why: 'Piove.',
        ),
      ],
      slots: const [
        AiSlot(
          id: 's1',
          type: 'calze',
          category: ItemCategory.vestiti,
          level: AiSlotLevel.useful,
          name: 'Calze',
          copies: 1,
          remaining: 1,
          addLabel: 'Aggiungi',
        ),
      ],
    );

    late TripModel stored;

    Future<void> load(TripModel trip) async {
      stored = trip;
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [stored]);
      when(() => mockRepository.updateTrip(any())).thenAnswer((inv) async {
        stored = inv.positionalArguments.first as TripModel;
      });
      when(
        () => mockRepository.setTripItemChecked(any(), any(), any()),
      ).thenAnswer((_) async {});
      await container.read(tripNotifierProvider.future);
    }

    final suitcase = TripModel(
      id: 't1',
      name: 'Lisbona',
      items: [packed('A'), packed('B')],
      aiResult: result(DateTime(2026, 11, 8)),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    TripNotifier notifier() => container.read(tripNotifierProvider.notifier);

    // ai_suitcase_changed parte dopo la lettura del meteo salvato.
    Future<List<Map<String, Object>>> changes() async {
      await pumpEventQueue();
      return verify(
        () => mockAnalytics.trackAiSuitcaseChanged(
          tripId: 't1',
          counts: captureAny(named: 'counts'),
          context: any(named: 'context'),
        ),
      ).captured.cast<Map<String, Object>>();
    }

    Future<void> verifyNoChange() async {
      await pumpEventQueue();
      verifyNever(
        () => mockAnalytics.trackAiSuitcaseChanged(
          tripId: any(named: 'tripId'),
          counts: any(named: 'counts'),
          context: any(named: 'context'),
        ),
      );
    }

    setUp(() => registerFallbackValue(<String, Object>{}));

    test('togliere un capo proposto: ai_suitcase_changed', () async {
      await load(suitcase);
      await notifier().updateTrip(suitcase.copyWith(items: [packed('A')]));
      final counts = (await changes()).single;
      expect(counts['removed'], 1);
      expect(counts['kept'], 1);
    });

    test('spuntare un capo non è una modifica', () async {
      await load(suitcase);
      await notifier().toggleItemCheck('t1', 'A');
      await verifyNoChange();
    });

    test('valigia senza proposta AI: nessun evento', () async {
      final manual = suitcase.copyWith(aiResult: null);
      await load(manual);
      await notifier().updateTrip(manual.copyWith(items: [packed('A')]));
      await verifyNoChange();
    });

    test(
      'la proposta rigenerata non conta; dopo si confronta con lei',
      () async {
        await load(suitcase);
        final regenerated = suitcase.copyWith(
          items: [packed('A')],
          aiResult: result(DateTime(2026, 11, 9)).copyWith(
            proposal: const [
              AiPackedItem(itemId: 'A', quantity: 1, reason: reason),
            ],
          ),
        );
        await notifier().updateTrip(regenerated);
        await verifyNoChange();

        await notifier().updateTrip(regenerated.copyWith(items: const []));
        final counts = (await changes()).single;
        expect(counts['proposed'], 1);
        expect(counts['removed'], 1);
      },
    );

    test('posto riempito: un capo aggiunto, dal posto', () async {
      await load(suitcase);
      await notifier().fillAiSlot('t1', 's1', packed('C'));
      final counts = (await changes()).single;
      expect(counts['added'], 1);
      expect(counts['added_from_slots'], 1);
      expect(counts['removed'], 0);
    });

    test('oggetti aggiunti al viaggio: ai_suitcase_changed', () async {
      await load(suitcase);
      when(() => mockRepository.addItemsToTrip(any(), any())).thenAnswer((
        inv,
      ) async {
        final added = inv.positionalArguments[1] as List<TripItem>;
        stored = stored.copyWith(items: [...stored.items, ...added]);
      });
      await notifier().addItemsToTrip('t1', [packed('D')]);
      final counts = (await changes()).single;
      expect(counts['added'], 1);
      expect(counts['added_from_slots'], 0);
      expect(counts['kept'], 2);
    });

    test('avviso scartato: ai_warning_dismissed una volta', () async {
      await load(suitcase);
      await notifier().updateTrip(
        suitcase.copyWith(
          aiResult: suitcase.aiResult!.copyWith(dismissedWarnings: ['w1']),
        ),
      );
      verify(
        () => mockAnalytics.trackAiWarningDismissed(
          code: 'rain_gear',
          level: 'important',
        ),
      ).called(1);
      await verifyNoChange();
    });

    test('due salvataggi sovrapposti contano l avviso una volta', () async {
      await load(suitcase);
      final saving = Completer<void>();
      when(() => mockRepository.updateTrip(any())).thenAnswer((inv) async {
        await saving.future;
        stored = inv.positionalArguments.first as TripModel;
      });
      final dismissed = suitcase.copyWith(
        aiResult: suitcase.aiResult!.copyWith(dismissedWarnings: ['w1']),
      );
      // Tutti e due partono dallo stesso viaggio, prima che uno finisca.
      final first = notifier().updateTrip(dismissed);
      final second = notifier().updateTrip(dismissed);
      saving.complete();
      await Future.wait([first, second]);

      verify(
        () => mockAnalytics.trackAiWarningDismissed(
          code: 'rain_gear',
          level: 'important',
        ),
      ).called(1);
    });

    test('rigenerata la valigia, lo stesso avviso si conta di nuovo', () async {
      await load(suitcase);
      await notifier().updateTrip(
        suitcase.copyWith(
          aiResult: suitcase.aiResult!.copyWith(dismissedWarnings: ['w1']),
        ),
      );
      final regenerated = suitcase.copyWith(
        aiResult: result(DateTime(2026, 11, 9)),
      );
      await notifier().updateTrip(regenerated);
      await notifier().updateTrip(
        regenerated.copyWith(
          aiResult: regenerated.aiResult!.copyWith(dismissedWarnings: ['w1']),
        ),
      );
      verify(
        () => mockAnalytics.trackAiWarningDismissed(
          code: 'rain_gear',
          level: 'important',
        ),
      ).called(2);
    });

    test('posto tolto: ai_slot_removed una volta', () async {
      await load(suitcase);
      await notifier().updateAiSlot(
        't1',
        's1',
        (s) => s.copyWith(removed: true),
      );
      verify(
        () => mockAnalytics.trackAiSlotRemoved(type: 'calze', level: 'useful'),
      ).called(1);
    });

    // Il primo salvataggio della valigia fatto dal lavoro AI (aggiunta di un
    // viaggio nuovo, Rigenera, o l'update di un id già salvato) non è una
    // modifica dell'utente.
    test('adoption_does_not_emit_suitcase_changed', () async {
      ItemModel house(String id) => ItemModel(
        id: id,
        houseId: 'h1',
        name: 'capo $id',
        category: ItemCategory.vestiti,
        quantity: 2,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final houseItems = [house('A'), house('B')];
      const setup = AiPackingSetup(houseId: 'h1');
      final fresh = result(DateTime(2026, 11, 9));

      // Rigenera: la valigia di prima ha un'altra proposta.
      await load(suitcase);
      final regenerated = adoptedTrip(
        trip: suitcase,
        proposal: fresh,
        setup: setup,
        houseItems: houseItems,
      );
      await notifier().updateTrip(regenerated);

      // Guardia "id già esistente": lo stesso viaggio si riscrive uguale.
      await notifier().updateTrip(regenerated);

      // Viaggio nuovo: arriva con addTrip.
      final newTrip = TripModel(
        id: 't2',
        name: 'Nuovo',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => mockRepository.addTrip(any())).thenAnswer((_) async {});
      await notifier().addTrip(
        adoptedTrip(
          trip: newTrip,
          proposal: fresh,
          setup: setup,
          houseItems: houseItems,
        ),
        source: 'new',
      );

      await verifyNoChange();
      verify(
        () => mockAnalytics.trackTripCreated(
          tripId: 't2',
          totalTrips: any(named: 'totalTrips'),
          daysToDeparture: any(named: 'daysToDeparture'),
          source: 'new',
        ),
      ).called(1);
    });
  });

  group('TripNotifier - updateAiSlot', () {
    TripModel tripWithSlot() => TripModel(
      id: 't1',
      name: 'Seul',
      items: const [],
      luggages: const [],
      aiResult: AiPackingResult(
        generatedAt: DateTime(2026, 11),
        houseId: 'h1',
        slots: const [
          AiSlot(
            id: 's-giacca',
            type: 'giacca',
            category: ItemCategory.vestiti,
            level: AiSlotLevel.important,
            name: 'Giacca invernale',
            copies: 1,
            remaining: 1,
            addLabel: 'Aggiungi la tua',
          ),
        ],
      ),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    bool toBuyIn(TripModel trip) => trip.aiResult!.slots!.single.toBuy;

    test('aggiorna subito lo stato e salva il viaggio', () async {
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [tripWithSlot()]);
      await container.read(tripNotifierProvider.future);

      final saving = Completer<void>();
      when(
        () => mockRepository.updateTrip(any()),
      ).thenAnswer((_) => saving.future);

      final done = container
          .read(tripNotifierProvider.notifier)
          .updateAiSlot('t1', 's-giacca', (s) => s.copyWith(toBuy: true));

      // Prima che il salvataggio finisca, lo stato è già cambiato.
      expect(
        toBuyIn(container.read(tripNotifierProvider).value!.single),
        isTrue,
      );

      saving.complete();
      await done;

      final saved =
          verify(() => mockRepository.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(toBuyIn(saved), isTrue);
      // Niente ricarica completa: getAllTrips solo nel build.
      verify(() => mockRepository.getAllTrips()).called(1);
    });

    test('se il salvataggio fallisce torna lo stato di prima', () async {
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [tripWithSlot()]);
      await container.read(tripNotifierProvider.future);

      final failure = Exception('save failed');
      when(() => mockRepository.updateTrip(any())).thenThrow(failure);

      await expectLater(
        container
            .read(tripNotifierProvider.notifier)
            .updateAiSlot('t1', 's-giacca', (s) => s.copyWith(toBuy: true)),
        throwsA(equals(failure)),
      );

      final state = container.read(tripNotifierProvider);
      expect(state, isA<AsyncData<List<TripModel>>>());
      expect(toBuyIn(state.value!.single), isFalse);
    });

    test('risultato senza posti: nessuna scrittura', () async {
      final legacy = tripWithSlot().copyWith(
        aiResult: AiPackingResult(
          generatedAt: DateTime(2026, 11),
          houseId: 'h1',
        ),
      );
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => [legacy]);
      await container.read(tripNotifierProvider.future);

      await container
          .read(tripNotifierProvider.notifier)
          .updateAiSlot('t1', 's-giacca', (s) => s.copyWith(toBuy: true));

      verifyNever(() => mockRepository.updateTrip(any()));
    });
  });

  group('TripNotifier - fillAiSlot', () {
    AiSlot slot({int remaining = 3}) => AiSlot(
      id: 's-magliette',
      type: 'magliette',
      category: ItemCategory.vestiti,
      level: AiSlotLevel.useful,
      name: 'Magliette',
      copies: 5,
      remaining: remaining,
      addLabel: 'Aggiungi le tue',
    );

    TripModel tripWith({List<TripItem> items = const [], int remaining = 3}) =>
        TripModel(
          id: 't1',
          name: 'Seul',
          items: items,
          luggages: const [],
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [slot(remaining: remaining)],
          ),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    TripItem item(String id, int quantity) => TripItem(
      id: id,
      name: 'T-shirt nera',
      category: ItemCategory.vestiti,
      quantity: quantity,
      originHouseId: 'h1',
    );

    Future<void> load(TripModel trip) async {
      when(() => mockRepository.getAllTrips()).thenAnswer((_) async => [trip]);
      await container.read(tripNotifierProvider.future);
    }

    TripModel current() => container.read(tripNotifierProvider).value!.single;

    test('pubblica il fill solo dopo la scrittura', () async {
      await load(tripWith());
      final saving = Completer<void>();
      when(
        () => mockRepository.updateTrip(any()),
      ).thenAnswer((_) => saving.future);

      final done = container
          .read(tripNotifierProvider.notifier)
          .fillAiSlot('t1', 's-magliette', item('i1', 2));

      expect(current().items, isEmpty);
      expect(current().aiResult!.slots!.single.remaining, 3);

      saving.complete();
      await done;

      final saved =
          verify(() => mockRepository.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(saved.items.single.id, 'i1');
      expect(saved.aiResult!.slots!.single.remaining, 1);
      verify(() => mockRepository.getAllTrips()).called(1);
    });

    test('aggiungere copie riapre solo la riga già spuntata', () async {
      final checked = item('i1', 1).copyWith(isChecked: true);
      final other = item('i2', 1).copyWith(isChecked: true);
      await load(tripWith(items: [checked, other]));
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await container
          .read(tripNotifierProvider.notifier)
          .fillAiSlot('t1', 's-magliette', item('i1', 1));

      expect(current().items.map((entry) => entry.isChecked), [false, true]);
    });

    test('slot_filled: livello e copie, dopo il salvataggio', () async {
      await load(tripWith());
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await container
          .read(tripNotifierProvider.notifier)
          .fillAiSlot('t1', 's-magliette', item('i1', 2));

      verify(
        () => mockAnalytics.trackSlotFilled(level: 'useful', copies: 2),
      ).called(1);
    });

    test('slot_filled non parte se il salvataggio fallisce', () async {
      await load(tripWith());
      when(() => mockRepository.updateTrip(any())).thenThrow(Exception('x'));

      await expectLater(
        container
            .read(tripNotifierProvider.notifier)
            .fillAiSlot('t1', 's-magliette', item('i1', 2)),
        throwsException,
      );

      verifyNever(
        () => mockAnalytics.trackSlotFilled(
          level: any(named: 'level'),
          copies: any(named: 'copies'),
        ),
      );
    });

    test('più copie di quelle rimaste: il posto si ferma a zero', () async {
      await load(tripWith());
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await container
          .read(tripNotifierProvider.notifier)
          .fillAiSlot('t1', 's-magliette', item('i1', 5));

      expect(current().aiResult!.slots!.single.remaining, 0);
      expect(current().items.single.quantity, 5);
    });

    test('lo stesso id si somma alle quantità già in valigia', () async {
      await load(tripWith(items: [item('i1', 2)]));
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await container
          .read(tripNotifierProvider.notifier)
          .fillAiSlot('t1', 's-magliette', item('i1', 1));

      expect(current().items, hasLength(1));
      expect(current().items.single.quantity, 3);
      expect(current().aiResult!.slots!.single.remaining, 2);
    });

    test('se il salvataggio fallisce torna lo stato di prima', () async {
      await load(tripWith());
      final failure = Exception('save failed');
      when(() => mockRepository.updateTrip(any())).thenThrow(failure);

      await expectLater(
        container
            .read(tripNotifierProvider.notifier)
            .fillAiSlot('t1', 's-magliette', item('i1', 2)),
        throwsA(equals(failure)),
      );

      expect(current().items, isEmpty);
      expect(current().aiResult!.slots!.single.remaining, 3);
    });

    test('posto, viaggio o risultato sconosciuti: nessuna scrittura', () async {
      await load(tripWith());
      final notifier = container.read(tripNotifierProvider.notifier);

      await notifier.fillAiSlot('t1', 'non-esiste', item('i1', 2));
      await notifier.fillAiSlot('altro-viaggio', 's-magliette', item('i1', 2));

      expect(current().items, isEmpty);
      expect(current().aiResult!.slots!.single.remaining, 3);
      verifyNever(() => mockRepository.updateTrip(any()));
    });

    test('risultato senza posti: nessuna scrittura', () async {
      await load(
        tripWith().copyWith(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
          ),
        ),
      );

      await container
          .read(tripNotifierProvider.notifier)
          .fillAiSlot('t1', 's-magliette', item('i1', 2));

      expect(current().items, isEmpty);
      verifyNever(() => mockRepository.updateTrip(any()));
    });
  });

  group('TripNotifier - coda delle modifiche alla valigia', () {
    late AppDatabase db;
    late MockItemRepository items;
    late ProviderContainer c;
    late ProviderContainer Function(SuitcaseEditsDao) build;

    /// La coda si scrive in background: si aspetta che compaia.
    Future<List<SuitcaseEdit>> pendingSoon() async {
      for (var i = 0; i < 50; i++) {
        final p = await db.suitcaseEditsDao.pending();
        if (p.isNotEmpty) return p;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return const [];
    }

    AiPackingResult result() => AiPackingResult(
      generatedAt: DateTime(2026, 11),
      houseId: 'h1',
      generatorVersion: 'v9',
      proposal: const [
        AiPackedItem(
          itemId: 'i1',
          quantity: 1,
          reason: AiReason(code: 'c', label: 'l', sentence: 's'),
        ),
      ],
    );

    TripItem item() => TripItem(
      id: 'i1',
      name: 'Nome privato',
      category: ItemCategory.vestiti,
      quantity: 1,
    );

    TripModel trip({bool withResult = true, bool withItem = true}) => TripModel(
      id: 't1',
      name: 'Seul',
      items: [if (withItem) item()],
      luggages: const [],
      departureDateTime: DateTime.now().add(const Duration(days: 30)),
      aiResult: withResult ? result() : null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    setUp(() {
      db = createTestDatabase();
      items = MockItemRepository();
      when(() => items.getItemsByIds(any())).thenAnswer(
        (_) async => [
          ItemModel(
            id: 'i1',
            houseId: 'h1',
            name: 'Nome privato',
            category: ItemCategory.vestiti,
            aiMetadata:
                '{"category":"vestiti","warmth":3,"name":"Nome privato"}',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );
      final sync = MockSyncOrchestrator();
      when(() => sync.requestSync()).thenReturn(null);
      final analytics = MockCoreAnalyticsService();
      when(() => analytics.trackTripUpdated()).thenAnswer((_) async {});
      build = (dao) => ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepository),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
          syncOrchestratorProvider.overrideWithValue(sync),
          itemRepositoryProvider.overrideWithValue(items),
          suitcaseEditsDaoProvider.overrideWithValue(dao),
          currentUserIdProvider.overrideWithValue('u-1'),
        ],
      );
      c = build(db.suitcaseEditsDao);
    });

    tearDown(() async {
      c.dispose();
      await closeTestDatabase(db);
    });

    Future<void> load(TripModel t, TripModel after) async {
      var calls = 0;
      when(
        () => mockRepository.getAllTrips(),
      ).thenAnswer((_) async => calls++ == 0 ? [t] : [after]);
      await c.read(tripNotifierProvider.future);
    }

    test(
      'togliere un proposto con updateTrip mette un evento in coda',
      () async {
        final after = trip(withItem: false);
        await load(trip(), after);
        when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

        await c.read(tripNotifierProvider.notifier).updateTrip(after);

        final pending = await pendingSoon();
        expect(pending, hasLength(1));
        expect(pending.single.action.dbValue, 'tolto');
        expect(pending.single.origin.dbValue, 'proposta');
        expect(pending.single.tripId, 't1');
        expect(pending.single.generatorVersion, 'v9');
        expect(pending.single.userId, 'u-1');
        expect(pending.single.itemKey, hasLength(64));
        expect(pending.single.card['appCategory'], isNotNull);
        expect(pending.single.card['category'], 'vestiti');
        expect(pending.single.card['warmth'], 3);
        expect(pending.single.toString(), isNot(contains('Nome privato')));
      },
    );

    test('senza utente non si mette niente in coda', () async {
      final after = trip(withItem: false);
      c.dispose();
      c = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepository),
          coreAnalyticsServiceProvider.overrideWithValue(
            MockCoreAnalyticsService(),
          ),
          syncOrchestratorProvider.overrideWithValue(MockSyncOrchestrator()),
          itemRepositoryProvider.overrideWithValue(items),
          suitcaseEditsDaoProvider.overrideWithValue(db.suitcaseEditsDao),
          currentUserIdProvider.overrideWithValue(null),
        ],
      );
      await load(trip(), after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
      when(
        () => (c.read(coreAnalyticsServiceProvider) as MockCoreAnalyticsService)
            .trackTripUpdated(),
      ).thenAnswer((_) async {});
      when(
        () => (c.read(syncOrchestratorProvider) as MockSyncOrchestrator)
            .requestSync(),
      ).thenReturn(null);

      await c.read(tripNotifierProvider.notifier).updateTrip(after);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await db.suitcaseEditsDao.pending(), isEmpty);
    });

    test('un salvataggio fallito non mette niente', () async {
      final after = trip(withItem: false);
      await load(trip(), after);
      when(
        () => mockRepository.updateTrip(any()),
      ).thenAnswer((_) async => throw Exception('disco pieno'));

      await expectLater(
        c.read(tripNotifierProvider.notifier).updateTrip(after),
        throwsException,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await db.suitcaseEditsDao.pending(), isEmpty);
    });

    test('un viaggio senza aiResult non mette niente', () async {
      final before = trip(withResult: false);
      final after = trip(withResult: false, withItem: false);
      await load(before, after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await c.read(tripNotifierProvider.notifier).updateTrip(after);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await db.suitcaseEditsDao.pending(), isEmpty);
    });

    test('add_page_done_records_added_items', () async {
      // "Fatto" della pagina di aggiunta: updateTrip sul viaggio attuale con
      // l'oggetto aggiunto e uno tolto. Origine utente per l'aggiunto.
      final before = trip();
      final after = before.copyWith(
        items: [
          TripItem(
            id: 'i2',
            name: 'Nome privato due',
            category: ItemCategory.vestiti,
            quantity: 1,
          ),
        ],
      );
      await load(before, after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await c.read(tripNotifierProvider.notifier).updateTrip(after);

      for (var i = 0; i < 50; i++) {
        if ((await db.suitcaseEditsDao.pending()).length >= 2) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final pending = await db.suitcaseEditsDao.pending();
      final byAction = {for (final e in pending) e.action.dbValue: e};
      expect(pending, hasLength(2));
      expect(byAction['aggiunto']?.origin.dbValue, 'utente');
      expect(byAction['tolto']?.origin.dbValue, 'proposta');
      expect(
        pending.any((e) => e.toString().contains('Nome privato')),
        isFalse,
      );
    });

    test('trip_info_change_records_no_edits', () async {
      // Date e tappe (Modifica viaggio) non sono una modifica della valigia.
      final before = trip();
      final after = before.copyWith(
        name: 'Altro nome',
        departureDateTime: DateTime.now().add(const Duration(days: 40)),
      );
      await load(before, after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await c.read(tripNotifierProvider.notifier).updateTrip(after);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await db.suitcaseEditsDao.pending(), isEmpty);
    });

    test('un DAO che non risponde mai non blocca updateTrip', () async {
      final after = trip(withItem: false);
      await load(trip(), after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
      final dao = MockSuitcaseEditsDao();
      registerFallbackValue(<SuitcaseEdit>[]);
      when(
        () => dao.enqueue(any()),
      ).thenAnswer((_) => Completer<void>().future);
      c.dispose();
      c = build(dao);
      await load(trip(), after);

      await c
          .read(tripNotifierProvider.notifier)
          .updateTrip(after)
          .timeout(const Duration(seconds: 2));

      expect(c.read(tripNotifierProvider).value!.single.items, isEmpty);
    });

    test('un consenso che lancia non cambia stato né esito', () async {
      final after = trip(withItem: false);
      final dao = noopSuitcaseEditsDao();
      c.dispose();
      c = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepository),
          coreAnalyticsServiceProvider.overrideWithValue(
            MockCoreAnalyticsService(),
          ),
          syncOrchestratorProvider.overrideWithValue(MockSyncOrchestrator()),
          itemRepositoryProvider.overrideWithValue(items),
          suitcaseEditsDaoProvider.overrideWithValue(dao),
          consentServiceProvider.overrideWith((ref) => throw StateError('x')),
        ],
      );
      await load(trip(), after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});
      final analytics = c.read(coreAnalyticsServiceProvider);
      when(
        () => (analytics as MockCoreAnalyticsService).trackTripUpdated(),
      ).thenAnswer((_) async {});
      when(
        () => (c.read(syncOrchestratorProvider) as MockSyncOrchestrator)
            .requestSync(),
      ).thenReturn(null);

      await c.read(tripNotifierProvider.notifier).updateTrip(after);

      verifyNever(() => dao.enqueue(any()));
      expect(c.read(tripNotifierProvider).hasError, isFalse);
      expect(c.read(tripNotifierProvider).value!.single.items, isEmpty);
    });

    test('un DAO che lancia non cambia stato né esito', () async {
      final after = trip(withItem: false);
      final dao = MockSuitcaseEditsDao();
      registerFallbackValue(<SuitcaseEdit>[]);
      when(() => dao.enqueue(any())).thenAnswer((_) async => throw 'rotto');
      c.dispose();
      c = build(dao);
      await load(trip(), after);
      when(() => mockRepository.updateTrip(any())).thenAnswer((_) async {});

      await c.read(tripNotifierProvider.notifier).updateTrip(after);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => dao.enqueue(any())).called(1);
      expect(c.read(tripNotifierProvider).hasError, isFalse);
      expect(c.read(tripNotifierProvider).value!.single.items, isEmpty);
    });
  });
}
