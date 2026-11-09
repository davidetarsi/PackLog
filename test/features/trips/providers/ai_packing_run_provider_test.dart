import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
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
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/features/trips/services/suitcase_analytics.dart';
import 'package:pack_log/features/trips/services/suitcase_outdated.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 11, 8);

class _Analytics extends Mock implements CoreAnalyticsService {}

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
  final sources = <String?>[];
  Object? writeError;

  void replace(List<TripModel> trips) => state = AsyncData(trips);

  @override
  Future<List<TripModel>> build() async => initial;

  @override
  Future<void> addTrip(TripModel model, {String? source}) async {
    sources.add(source);
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

AiPackingRequest _request(
  TripModel trip, {
  required bool isNew,
  String? tripSource,
  bool isRegeneration = false,
  List<String> setupChanged = const [],
  TripWeather? weather,
}) => AiPackingRequest(
  trip: trip,
  isNew: isNew,
  tripSource: tripSource,
  weather: weather,
  setup: const AiPackingSetup(houseId: 'h1', luggageId: 'l1'),
  job: PackTripJob(
    body: const {'trip': {}},
    houseId: 'h1',
    title: 'Islanda',
    nights: 3,
    isRegeneration: isRegeneration,
    setupChanged: setupChanged,
  ),
);

void main() {
  late _FakeService service;
  late _FakeTrips trips;
  late _FakeOnboarding onboarding;
  late _FakeMonitoring monitoring;
  late _Analytics analytics;
  late ProviderContainer container;

  void build({List<TripModel> existing = const [], bool itemsFail = false}) {
    service = _FakeService();
    trips = _FakeTrips(existing);
    onboarding = _FakeOnboarding();
    monitoring = _FakeMonitoring();
    analytics = _Analytics();
    container = ProviderContainer(
      overrides: [
        packTripServiceProvider.overrideWithValue(service),
        tripNotifierProvider.overrideWith(() => trips),
        itemNotifierProvider(
          'h1',
        ).overrideWith(() => _FakeItems([_house('a')], fails: itemsFail)),
        postLoginOnboardingProvider.overrideWith(() => onboarding),
        monitoringServiceProvider.overrideWithValue(monitoring),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
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
    registerFallbackValue(<String, Object>{});
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

  test('shape_is_from_request_trip_not_arrival_trip', () async {
    final sent = _trip('t1').copyWith(departureDateTime: DateTime(2030, 1, 10));
    build(existing: [sent]);
    await container.read(tripNotifierProvider.future);
    run().start(_request(sent, isNew: false));
    await settle();

    // Durante la generazione l'utente sposta la partenza.
    trips.replace([sent.copyWith(departureDateTime: DateTime(2030, 1, 20))]);
    service.pending.complete(_result());
    await settle();

    final saved = trips.updated.single;
    expect(saved.aiResult?.tripShape, AiTripShape.of(sent));
    expect(suitcaseOutdated(saved, now: DateTime(2029)), isTrue);
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
      () => analytics.trackFirstSuitcaseGenerated(
        slotsImportant: 0,
        slotsProposed: 0,
        slotsTotal: 0,
        tripItems: 1,
        fromFirstRun: true,
      ),
    ).called(1);

    run().clear();
    run().start(_request(_trip('t2'), isNew: true));
    service.pending.complete(_result());
    await settle();
    expect(onboarding.completed, 2);
    verifyNever(
      () => analytics.trackFirstSuitcaseGenerated(
        slotsImportant: any(named: 'slotsImportant'),
        slotsProposed: any(named: 'slotsProposed'),
        slotsTotal: any(named: 'slotsTotal'),
        tripItems: any(named: 'tripItems'),
        fromFirstRun: any(named: 'fromFirstRun'),
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

  /// Gli `ai_suitcase_finished` registrati finora: esito e proprietà.
  List<(String, Map<String, Object>)> finished() {
    final calls = verify(
      () => analytics.trackAiSuitcaseFinished(
        outcome: captureAny(named: 'outcome'),
        durationMs: any(named: 'durationMs'),
        tripId: 't1',
        properties: captureAny(named: 'properties'),
      ),
    ).captured;
    return [
      for (var i = 0; i < calls.length; i += 2)
        (calls[i] as String, calls[i + 1] as Map<String, Object>),
    ];
  }

  test('finished_ok_once_per_attempt', () async {
    build();
    run().start(
      _request(
        _trip('t1'),
        isNew: true,
        isRegeneration: true,
        setupChanged: const ['washer'],
      ),
    );
    service.pending.completeError(const PackTripException('boom'));
    await settle();
    final retried = run().retry();
    await settle();
    service.pending.complete(_result());
    await retried;
    await settle();

    final events = finished();
    expect([for (final e in events) e.$1], ['error', 'ok']);
    final ok = events.last.$2;
    expect(ok['nights'], 3);
    expect(ok['stops'], 0);
    expect(ok['is_regeneration'], isTrue);
    expect(ok['setup_changed'], ['washer']);
    expect(ok['proposal_items'], 1);
    expect(ok['slots_count'], 0);
    expect(ok['wardrobe_items'], 1);
    expect(ok.containsKey('retry_save'), isFalse);
    // Non c'è più l'annullamento.
    expect([for (final e in events) e.$1], isNot(contains('cancelled')));
  });

  test('finished_credits_also_tracks_limit', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.completeError(const PackTripCreditsException());
    await settle();

    expect(finished().single.$1, 'credits');
    verify(() => analytics.trackAiLimitReached(feature: 'suitcase')).called(1);
    // Crediti finiti: caso previsto, non un guasto.
    expect(monitoring.captured, isEmpty);
  });

  test('finished_network_for_timeout_is_not_reported', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.completeError(const PackTripNetworkException('timeout'));
    await settle();

    expect(finished().single.$1, 'network');
    expect(monitoring.captured, isEmpty);
    verifyNever(() => analytics.trackAiLimitReached(feature: 'suitcase'));
  });

  test('finished_left_wait_when_detached', () async {
    build();
    run().attach();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();
    run().clear();
    run().detach();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();

    expect([for (final e in finished()) e.$2['left_wait']], [false, true]);
  });

  test('finished_save_failed_and_retry_save', () async {
    build();
    trips.writeError = StateError('disco');
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();

    // Errore silenzioso: va a Sentry.
    expect(monitoring.captured, hasLength(1));
    expect(monitoring.captured.single, isA<StateError>());

    trips.writeError = null;
    await run().retry();
    await settle();

    // Un solo pack-trip; due eventi: il salvataggio fallito e poi riuscito.
    expect(service.calls, 1);
    final events = finished();
    expect([for (final e in events) e.$1], ['save_failed', 'ok']);
    expect(events.first.$2.containsKey('retry_save'), isFalse);
    expect(events.last.$2['retry_save'], isTrue);
  });

  test('finished_invalid_response_is_error', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.completeError(const PackTripInvalidResponseException('x'));
    await settle();

    expect(finished().single.$1, 'error');
    expect(monitoring.captured, hasLength(1));
  });

  test('finished_has_no_personal_text', () async {
    build();
    run().start(_request(_trip('t1', name: 'Segreto'), isNew: true));
    service.pending.complete(_result());
    await settle();

    final props = finished().single.$2;
    expect(props.toString(), isNot(contains('Segreto')));
    expect(props.toString(), isNot(contains('Islanda')));
  });

  test('trip_created_source_reuse', () async {
    build();
    run().start(_request(_trip('t1'), isNew: true, tripSource: 'reuse'));
    service.pending.complete(_result());
    await settle();
    expect(trips.sources, ['reuse']);

    run().clear();
    run().start(_request(_trip('t2'), isNew: true));
    service.pending.complete(_result());
    await settle();
    expect(trips.sources, ['reuse', 'new']);
  });

  test('finished_uses_weather_from_request', () async {
    build();
    final weather = TripWeather(
      signature: 's',
      fetchedAt: _now,
      stops: [
        StopWeather(
          name: 'Reykjavik',
          from: DateTime(2026, 11, 10),
          to: DateTime(2026, 11, 14),
          source: WeatherSource.climate,
          tempMin: 1.2,
          tempMax: 6.4,
          rainDays: 3,
        ),
      ],
    );
    run().start(_request(_trip('t1'), isNew: true, weather: weather));
    service.pending.complete(_result());
    await settle();

    final props = finished().single.$2;
    expect(props['temp_max_band'], tempBand(6.4));
    expect(props['temp_min_band'], tempBand(1.2));
    expect(props['rain_days'], 3);
    expect(props['weather_source'], 'climate');
    // Il nome della tappa non esce mai.
    expect(props.toString(), isNot(contains('Reykjavik')));

    // Senza meteo nella richiesta l'evento parte senza clima.
    run().clear();
    run().start(_request(_trip('t1'), isNew: true));
    service.pending.complete(_result());
    await settle();
    expect(finished().last.$2.containsKey('temp_max_band'), isFalse);
  });
}
