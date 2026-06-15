import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _MockItemRepository extends Mock implements ItemRepository {}

class _MockMonitoringService extends Mock implements AppMonitoringService {}

void main() {
  late _MockItemRepository itemRepo;
  late _MockMonitoringService monitoring;
  late TripLifecycleService service;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(SentryLevel.error);
  });

  setUp(() {
    itemRepo = _MockItemRepository();
    monitoring = _MockMonitoringService();
    service = TripLifecycleService(
      itemRepository: itemRepo,
      monitoringService: monitoring,
    );

    when(
      () => itemRepo.moveItemsToHouse(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => monitoring.captureException(
        any(),
        stackTrace: any(named: 'stackTrace'),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
      ),
    ).thenReturn(null);
  });

  TripModel completedTrip({
    required String id,
    required String destinationHouseId,
    required List<TripItem> items,
  }) {
    // Completed = returnDateTime in the past
    return TripModel(
      id: id,
      name: 'Trip $id',
      items: items,
      luggages: [],
      departureDateTime: DateTime.now().subtract(const Duration(days: 7)),
      returnDateTime: DateTime.now().subtract(const Duration(days: 1)),
      destinationHouseId: destinationHouseId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  TripModel upcomingTrip({
    required String id,
    DateTime? departureDateTime,
  }) {
    return TripModel(
      id: id,
      name: 'Upcoming $id',
      items: [],
      luggages: [],
      departureDateTime:
          departureDateTime ?? DateTime.now().add(const Duration(days: 3)),
      returnDateTime: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  TripModel activeTrip({required String id, DateTime? returnDateTime}) {
    return TripModel(
      id: id,
      name: 'Active $id',
      items: [],
      luggages: [],
      departureDateTime: DateTime.now().subtract(const Duration(days: 1)),
      returnDateTime:
          returnDateTime ?? DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  TripItem item({
    required String id,
    required String originHouseId,
  }) {
    return TripItem(
      id: id,
      name: 'item-$id',
      category: ItemCategory.varie,
      quantity: 1,
      originHouseId: originHouseId,
    );
  }

  group('transferItemsForCompletedTrips', () {
    test(
      'moves items grouped by origin house and returns affected house IDs',
      () async {
        // === ARRANGE ===
        final trip = completedTrip(
          id: 'trip-1',
          destinationHouseId: 'house-dest',
          items: [
            item(id: 'i1', originHouseId: 'house-A'),
            item(id: 'i2', originHouseId: 'house-A'),
            item(id: 'i3', originHouseId: 'house-B'),
          ],
        );

        // === ACT ===
        final affected = await service.transferItemsForCompletedTrips([trip]);

        // === ASSERT ===
        // Grouped per origin: 1 call per origin house (no N+1)
        verify(
          () => itemRepo.moveItemsToHouse(['i1', 'i2'], 'house-A', 'house-dest'),
        ).called(1);
        verify(
          () => itemRepo.moveItemsToHouse(['i3'], 'house-B', 'house-dest'),
        ).called(1);
        // Affected houses include both origins + destination
        expect(affected, {'house-A', 'house-B', 'house-dest'});
      },
    );

    test('skips non-completed trips', () async {
      final trips = [
        upcomingTrip(id: 'up-1'),
        activeTrip(id: 'act-1'),
      ];

      final affected = await service.transferItemsForCompletedTrips(trips);

      verifyNever(() => itemRepo.moveItemsToHouse(any(), any(), any()));
      expect(affected, isEmpty);
    });

    test('skips completed trips without destinationHouseId', () async {
      final trip = TripModel(
        id: 't',
        name: 'No dest',
        items: [item(id: 'i1', originHouseId: 'house-A')],
        luggages: [],
        departureDateTime: DateTime.now().subtract(const Duration(days: 7)),
        returnDateTime: DateTime.now().subtract(const Duration(days: 1)),
        // destinationHouseId: null
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final affected = await service.transferItemsForCompletedTrips([trip]);

      verifyNever(() => itemRepo.moveItemsToHouse(any(), any(), any()));
      expect(affected, isEmpty);
    });

    test('skips items with empty originHouseId or origin == destination',
        () async {
      final trip = completedTrip(
        id: 'trip-1',
        destinationHouseId: 'house-dest',
        items: [
          item(id: 'i1', originHouseId: ''), // empty origin
          item(id: 'i2', originHouseId: 'house-dest'), // origin == dest
          item(id: 'i3', originHouseId: 'house-A'), // real candidate
        ],
      );

      final affected = await service.transferItemsForCompletedTrips([trip]);

      verify(
        () => itemRepo.moveItemsToHouse(['i3'], 'house-A', 'house-dest'),
      ).called(1);
      verifyNoMoreInteractions(itemRepo);
      expect(affected, {'house-A', 'house-dest'});
    });

    test(
      'captures exception via monitoring on moveItemsToHouse failure '
      'and continues with remaining groups',
      () async {
        when(
          () => itemRepo.moveItemsToHouse(any(), 'house-A', any()),
        ).thenThrow(StateError('boom'));

        final trip = completedTrip(
          id: 'trip-1',
          destinationHouseId: 'house-dest',
          items: [
            item(id: 'i1', originHouseId: 'house-A'), // will fail
            item(id: 'i2', originHouseId: 'house-B'), // should still process
          ],
        );

        final affected = await service.transferItemsForCompletedTrips([trip]);

        verify(
          () => monitoring.captureException(
            any(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace'),
            tags: any(
              named: 'tags',
              that: predicate<Map<String, String>>(
                (m) =>
                    m['operation'] == 'auto_transfer_items' &&
                    m['trip_id'] == 'trip-1' &&
                    m['from_house'] == 'house-A' &&
                    m['to_house'] == 'house-dest',
              ),
            ),
          ),
        ).called(1);
        // house-B group must still be processed
        verify(
          () => itemRepo.moveItemsToHouse(['i2'], 'house-B', 'house-dest'),
        ).called(1);
        // Only the successful group's houses are reported as affected
        expect(affected, {'house-B', 'house-dest'});
      },
    );
  });

  group('computeNextStatusChange', () {
    test('returns earliest future departure across upcoming trips', () {
      final now = DateTime.now();
      final t1 = upcomingTrip(
        id: 't1',
        departureDateTime: now.add(const Duration(hours: 5)),
      );
      final t2 = upcomingTrip(
        id: 't2',
        departureDateTime: now.add(const Duration(hours: 2)), // earlier
      );

      final next = service.computeNextStatusChange([t1, t2]);

      expect(
        next,
        equals(t2.departureDateTime),
      );
    });

    test('returns earliest future return across active trips', () {
      final now = DateTime.now();
      final a1 = activeTrip(
        id: 'a1',
        returnDateTime: now.add(const Duration(hours: 8)),
      );
      final a2 = activeTrip(
        id: 'a2',
        returnDateTime: now.add(const Duration(hours: 1)), // earlier
      );

      final next = service.computeNextStatusChange([a1, a2]);

      expect(next, equals(a2.returnDateTime));
    });

    test('returns null for empty trip list', () {
      expect(service.computeNextStatusChange([]), isNull);
    });

    test('ignores completed trips (no upcoming status change)', () {
      final trip = completedTrip(
        id: 'done',
        destinationHouseId: 'house-dest',
        items: [],
      );

      final next = service.computeNextStatusChange([trip]);

      expect(next, isNull);
    });

    test('ignores past departure/return dates', () {
      final now = DateTime.now();
      final trip = TripModel(
        id: 'past',
        name: 'past',
        items: [],
        luggages: [],
        // Both dates in the past — already completed, no future change
        departureDateTime: now.subtract(const Duration(days: 3)),
        returnDateTime: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      final next = service.computeNextStatusChange([trip]);

      expect(next, isNull);
    });
  });
}
