import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/services/trip_weather_service.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

class _MockAnalytics extends Mock implements CoreAnalyticsService {}

class _MockMonitoring extends Mock implements AppMonitoringService {}

late _MockAnalytics _analytics;
late _MockMonitoring _monitoring;

class _FakeTripNotifier extends TripNotifier {
  _FakeTripNotifier(this.trips);
  final List<TripModel> trips;
  @override
  Future<List<TripModel>> build() async => trips;
}

class _FakeHouseNotifier extends HouseNotifier {
  @override
  Future<List<HouseModel>> build() async => const [];
}

/// Servizio finto: conta le chiamate e risponde come gli si dice.
class _FakeService extends TripWeatherService {
  int calls = 0;
  Object? error;

  /// Quanto è vecchio il meteo che restituisce.
  Duration age = Duration.zero;

  @override
  Future<TripWeather> fetch(TripWeatherRequest request) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return TripWeather(
      signature: request.signature,
      fetchedAt: DateTime.now().subtract(age),
      stops: [
        for (final stop in request.stops)
          StopWeather(
            name: stop.name,
            from: stop.from,
            to: stop.to,
            source: WeatherSource.forecast,
            tempMin: 10,
            tempMax: 20,
          ),
      ],
    );
  }
}

TripModel _trip({int returnInDays = 4}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return TripModel(
    id: 't1',
    name: 'Lisbona',
    departureDateTime: today.add(const Duration(days: 2)),
    returnDateTime: today.add(Duration(days: returnInDays)),
    destinationLocation: LocationSuggestionModel(
      placeId: 'p',
      displayName: 'Lisbona, Portogallo',
      city: 'Lisbona',
      lat: 38.7,
      lon: -9.1,
    ),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

ProviderContainer _container(_FakeService service, TripModel trip) {
  final container = ProviderContainer(
    overrides: [
      tripNotifierProvider.overrideWith(() => _FakeTripNotifier([trip])),
      houseNotifierProvider.overrideWith(_FakeHouseNotifier.new),
      tripWeatherServiceProvider.overrideWithValue(service),
      coreAnalyticsServiceProvider.overrideWithValue(_analytics),
      monitoringServiceProvider.overrideWithValue(_monitoring),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _analytics = _MockAnalytics();
    _monitoring = _MockMonitoring();
  });

  void verifyNoSentry() => verifyNever(
    () => _monitoring.captureException(
      any(),
      stackTrace: any(named: 'stackTrace'),
      tags: any(named: 'tags'),
    ),
  );

  group('tetti ed errori', () {
    Future<void> load(Object error) async {
      final service = _FakeService()..error = error;
      await _container(
        service,
        _trip(),
      ).read(tripWeatherNotifierProvider('t1').future);
    }

    test('tetto finito: ai_limit_reached, niente Sentry', () async {
      await load(const TripWeatherCapException());
      verify(
        () => _analytics.trackAiLimitReached(feature: 'weather'),
      ).called(1);
      verifyNoSentry();
    });

    test('errore della funzione: in Sentry', () async {
      await load(const TripWeatherException('HTTP 500'));
      verify(
        () => _monitoring.captureException(
          any(that: isA<TripWeatherException>()),
          stackTrace: any(named: 'stackTrace'),
          tags: {'operation': 'trip_weather'},
        ),
      ).called(1);
      verifyNever(
        () => _analytics.trackAiLimitReached(feature: any(named: 'feature')),
      );
    });

    test('rete assente: né evento né Sentry', () async {
      await load(const TripWeatherNetworkException('rete: x'));
      verifyNever(
        () => _analytics.trackAiLimitReached(feature: any(named: 'feature')),
      );
      verifyNoSentry();
    });
  });

  test('senza cache chiama e salva; poi la cache basta', () async {
    final service = _FakeService();
    final first = _container(service, _trip());
    final state = await first.read(tripWeatherNotifierProvider('t1').future);
    expect(state, isA<TripWeatherReady>());
    expect(service.calls, 1);

    // Un'altra apertura (nuovo container) trova la cache fresca.
    final second = _container(service, _trip());
    await second.read(tripWeatherNotifierProvider('t1').future);
    expect(service.calls, 1);
  });

  test('viaggio cambiato: la cache non vale', () async {
    final service = _FakeService();
    await _container(
      service,
      _trip(),
    ).read(tripWeatherNotifierProvider('t1').future);
    await _container(
      service,
      _trip(returnInDays: 6),
    ).read(tripWeatherNotifierProvider('t1').future);
    expect(service.calls, 2);
  });

  test('Aggiorna con meteo di meno di un ora non richiama', () async {
    final service = _FakeService();
    final container = _container(service, _trip());
    await container.read(tripWeatherNotifierProvider('t1').future);
    final refreshed = await container
        .read(tripWeatherNotifierProvider('t1').notifier)
        .refresh();
    expect(refreshed, isFalse);
    expect(service.calls, 1);
  });

  test(
    'Aggiorna con meteo di due ore richiama, anche entro le 24 ore',
    () async {
      final service = _FakeService()..age = const Duration(hours: 2);
      final container = _container(service, _trip());
      await container.read(tripWeatherNotifierProvider('t1').future);

      service.age = Duration.zero;
      final refreshed = await container
          .read(tripWeatherNotifierProvider('t1').notifier)
          .refresh();
      expect(refreshed, isTrue);
      expect(service.calls, 2);
      final state = container
          .read(tripWeatherNotifierProvider('t1'))
          .valueOrNull;
      expect(
        (state as TripWeatherReady).weather.isFresh(
          DateTime.now(),
          maxAge: const Duration(minutes: 1),
        ),
        isTrue,
      );
    },
  );

  test('aprendo di nuovo con meteo di due ore usa la copia', () async {
    final service = _FakeService()..age = const Duration(hours: 2);
    await _container(
      service,
      _trip(),
    ).read(tripWeatherNotifierProvider('t1').future);
    await _container(
      service,
      _trip(),
    ).read(tripWeatherNotifierProvider('t1').future);
    expect(service.calls, 1);
  });

  test('tetto finito senza copia', () async {
    final service = _FakeService()..error = const TripWeatherCapException();
    final state = await _container(
      service,
      _trip(),
    ).read(tripWeatherNotifierProvider('t1').future);
    expect(state, isA<TripWeatherCapReached>());
  });

  test('errore senza copia, poi Aggiorna riprova', () async {
    final service = _FakeService()..error = const TripWeatherException('x');
    final container = _container(service, _trip());
    final failed = await container.read(
      tripWeatherNotifierProvider('t1').future,
    );
    expect(failed, isA<TripWeatherFailed>());

    service.error = null;
    await container.read(tripWeatherNotifierProvider('t1').notifier).refresh();
    expect(
      container.read(tripWeatherNotifierProvider('t1')).valueOrNull,
      isA<TripWeatherReady>(),
    );
    expect(service.calls, 2);
  });

  test('copia vecchia dello stesso viaggio se la chiamata fallisce', () async {
    final service = _FakeService();
    final trip = _trip();
    final plan =
        planTripWeather(trip, houses: const [], today: DateTime.now())
            as TripWeatherRequest;
    await TripWeatherCache().write(
      't1',
      TripWeather(
        signature: plan.signature,
        fetchedAt: DateTime.now().subtract(const Duration(days: 2)),
        stops: const [],
      ),
    );
    service.error = const TripWeatherCapException();
    final state = await _container(
      service,
      trip,
    ).read(tripWeatherNotifierProvider('t1').future);
    expect(state, isA<TripWeatherReady>());
    expect(service.calls, 1);
  });

  test('viaggio senza date: niente chiamata', () async {
    final service = _FakeService();
    final trip = TripModel(
      id: 't1',
      name: 'Da decidere',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final state = await _container(
      service,
      trip,
    ).read(tripWeatherNotifierProvider('t1').future);
    expect(state, isA<TripWeatherNotAvailable>());
    expect(service.calls, 0);
  });
}
