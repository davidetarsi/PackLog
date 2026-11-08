import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/pack_trip_job.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_analytics.dart';

final _now = DateTime(2026, 11, 8);

class _FakeService extends PackTripService {
  _FakeService() : super(token: () => 'jwt');
  var calls = 0;
  Completer<AiPackingResult> pending = Completer();

  @override
  Future<AiPackingResult> generate(
    Map<String, dynamic> body, {
    required String houseId,
  }) {
    calls++;
    pending = Completer();
    return pending.future;
  }
}

class _FakeTrips extends TripNotifier {
  _FakeTrips(this.initial);
  final List<TripModel> initial;
  final added = <TripModel>[];
  final updated = <TripModel>[];
  Object? writeError;

  void replace(List<TripModel> trips) => state = AsyncData(trips);

  @override
  Future<List<TripModel>> build() async => initial;

  @override
  Future<void> addTrip(TripModel model) async {
    if (writeError != null) throw writeError!;
    added.add(model);
    state = AsyncData([...?state.valueOrNull, model]);
  }

  @override
  Future<void> updateTrip(TripModel model) async {
    if (writeError != null) throw writeError!;
    updated.add(model);
  }
}

class _FakeItems extends ItemNotifier {
  _FakeItems(this.items, {this.fails = false});
  final List<ItemModel> items;
  final bool fails;

  @override
  Future<List<ItemModel>> build(String houseId) async {
    if (fails) throw StateError('items');
    return items;
  }
}

class _FakeOnboarding extends PostLoginOnboarding {
  var completed = 0;

  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(step: OnboardingStep.firstTrip);

  @override
  Future<void> completeFirstTrip() async => completed++;
}

class _FakeMonitoring extends AppMonitoringService {
  final captured = <Object>[];

  @override
  void captureException(
    Object exception, {
    StackTrace? stackTrace,
    SentryLevel level = SentryLevel.error,
    Map<String, String>? tags,
  }) => captured.add(exception);
}

ItemModel _house(String id) => ItemModel(
  id: id,
  houseId: 'h1',
  name: 'Capo $id',
  category: ItemCategory.vestiti,
  quantity: 3,
  createdAt: _now,
  updatedAt: _now,
);

AiPackingResult _result() => AiPackingResult(
  generatedAt: _now,
  houseId: 'h1',
  proposal: [
    const AiPackedItem(
      itemId: 'a',
      quantity: 1,
      reason: AiReason(code: 'c', label: 'l', sentence: 's'),
    ),
  ],
  slots: const [],
);

TripModel _trip(String id, {String name = 'Viaggio'}) =>
    TripModel(id: id, name: name, createdAt: _now, updatedAt: _now);

AiPackingRequest _request(TripModel trip, {required bool isNew}) =>
    AiPackingRequest(
      trip: trip,
      isNew: isNew,
      setup: const AiPackingSetup(houseId: 'h1', luggageId: 'l1'),
      job: const PackTripJob(
        body: {'trip': {}},
        houseId: 'h1',
        title: 'Islanda',
        nights: 3,
      ),
    );

void main() {
  late _FakeService service;
  late _FakeTrips trips;
  late _FakeOnboarding onboarding;
  late _FakeMonitoring monitoring;
  late MockAnalyticsService analytics;
  late ProviderContainer container;

  void build({List<TripModel> existing = const [], bool itemsFail = false}) {
    service = _FakeService();
    trips = _FakeTrips(existing);
    onboarding = _FakeOnboarding();
    monitoring = _FakeMonitoring();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        packTripServiceProvider.overrideWithValue(service),
        tripNotifierProvider.overrideWith(() => trips),
        itemNotifierProvider(
          'h1',
        ).overrideWith(() => _FakeItems([_house('a')], fails: itemsFail)),
        postLoginOnboardingProvider.overrideWith(() => onboarding),
        monitoringServiceProvider.overrideWithValue(monitoring),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(container.dispose);
    // Il provider deve restare vivo come in produzione.
    container.listen(aiPackingRunProvider, (_, _) {});
  }

  AiPackingRun run() => container.read(aiPackingRunProvider.notifier);
  AiPackingRunState state() => container.read(aiPackingRunProvider);

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(_trip('fallback'));
  });

  test('start_returns_false_while_running', () {
    build();
    expect(run().start(_request(_trip('t1'), isNew: true)), isTrue);
    expect(state(), isA<AiRunRunning>());
    expect(run().start(_request(_trip('t2'), isNew: true)), isFalse);
    expect(service.calls, 1);
  });

  test('new_trip_is_added_only_on_success', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    await settle();
    expect(trips.added, isEmpty);
    expect(trips.updated, isEmpty);

    service.pending.complete(_result());
    await settle();

    expect(trips.added, hasLength(1));
    expect(trips.updated, isEmpty);
    final saved = trips.added.single;
    expect(saved.id, 't1');
    expect([for (final i in saved.items) i.id], ['a']);
    expect(saved.aiResult, isNotNull);
    final done = state();
    expect(done, isA<AiRunDone>());
    expect((done as AiRunDone).tripId, 't1');
    expect(done.itemsError, isFalse);
    // Il provider non si azzera da solo.
    run().clear();
    expect(state(), isA<AiRunIdle>());
  });

  test('is_new_with_existing_id_updates_instead_of_adding', () async {
    // Il viaggio c'è già (per esempio salvato da un tentativo precedente).
    build(existing: [_trip('t1')]);
    await container.read(tripNotifierProvider.future);
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();

    expect(trips.added, isEmpty);
    expect(trips.updated, hasLength(1));
    expect(trips.updated.single.id, 't1');
    expect(trips.updated.single.aiResult, isNotNull);
    expect(state(), isA<AiRunDone>());
  });

  test('failure_saves_nothing', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.completeError(const PackTripException('boom'));
    await settle();

    expect(trips.added, isEmpty);
    expect(trips.updated, isEmpty);
    expect(state(), isA<AiRunFailed>());
    expect(monitoring.captured, hasLength(1));
  });

  test('network_failure_is_not_reported', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.completeError(const PackTripNetworkException('rete'));
    await settle();
    expect(state(), isA<AiRunFailed>());
    expect(monitoring.captured, isEmpty);
  });

  test('retry_runs_again_from_failed_only', () async {
    build();
    await run().retry();
    expect(service.calls, 0);
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.completeError(const PackTripException('boom'));
    await settle();
    final retried = run().retry();
    await settle();
    expect(service.calls, 2);
    expect(state(), isA<AiRunRunning>());
    service.pending.complete(_result());
    await retried;
    expect(state(), isA<AiRunDone>());
  });

  test('regenerate_applies_to_current_trip', () async {
    build(existing: [_trip('t1', name: 'Prima')]);
    await container.read(tripNotifierProvider.future);
    run().start(_request(_trip('t1', name: 'Prima'), isNew: false));
    await settle();

    // Nel frattempo l'utente rinomina il viaggio.
    trips.replace([_trip('t1', name: 'Dopo')]);
    service.pending.complete(_result());
    await settle();

    expect(trips.added, isEmpty);
    expect(trips.updated, hasLength(1));
    expect(trips.updated.single.name, 'Dopo');
    expect(trips.updated.single.aiResult, isNotNull);
    expect(state(), isA<AiRunDone>());
  });

  test('regenerate_on_deleted_trip_is_discarded', () async {
    build(existing: [_trip('t1')]);
    await container.read(tripNotifierProvider.future);
    run().start(_request(_trip('t1'), isNew: false));
    await settle();

    trips.replace(const []);
    service.pending.complete(_result());
    await settle();

    expect(trips.added, isEmpty);
    expect(trips.updated, isEmpty);
    expect(state(), isA<AiRunIdle>());
    expect(onboarding.completed, 0);
  });

  test('items_unreadable_still_saves', () async {
    build(itemsFail: true);
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();

    expect(trips.added, hasLength(1));
    expect(trips.added.single.items, isEmpty);
    expect(trips.added.single.aiResult, isNotNull);
    expect((state() as AiRunDone).itemsError, isTrue);
  });

  test('first_trip_and_events_on_success', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();
    expect(onboarding.completed, 1);
    verify(
      () => analytics.logEvent(
        'first_suitcase_generated',
        properties: any(
          named: 'properties',
          that: containsPair('from_first_run', true),
        ),
      ),
    ).called(1);

    run().clear();
    run().start(_request(_trip('t2'), isNew: true));
    service.pending.complete(_result());
    await settle();
    expect(onboarding.completed, 2);
    verifyNever(
      () => analytics.logEvent(
        'first_suitcase_generated',
        properties: any(named: 'properties'),
      ),
    );
  });

  test('save_failure_keeps_response_and_retry_does_not_regenerate', () async {
    build();
    trips.writeError = StateError('disco');
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();
    expect(state(), isA<AiRunFailed>());

    trips.writeError = null;
    await run().retry();
    expect(service.calls, 1);
    expect(trips.added, hasLength(1));
    expect(state(), isA<AiRunDone>());
  });

  test('clear_while_running_discards_the_result', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    run().clear();
    service.pending.complete(_result());
    await settle();
    expect(trips.added, isEmpty);
    expect(state(), isA<AiRunIdle>());
  });
}
