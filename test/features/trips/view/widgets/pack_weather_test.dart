import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_weather.dart';

import '../../../../helpers/memory_asset_loader.dart';

TripModel _viaggio({required DateTime departure, required DateTime returnAt}) {
  return TripModel(
    id: 'v1',
    name: 'Viaggio',
    departureDateTime: departure,
    returnDateTime: returnAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isSaved: false,
    items: const [],
    legs: const [],
  );
}

/// Meteo finto: conta le letture e risponde "non riuscito", che la sezione
/// mostra sempre con il suo titolo.
class _FakeWeather extends TripWeatherNotifier {
  _FakeWeather(this.reads);
  final List<String> reads;

  @override
  Future<TripWeatherState> build(String tripId) async {
    reads.add(tripId);
    return const TripWeatherFailed();
  }
}

/// Meteo pronto; "Aggiorna" risponde che era già aggiornato.
class _FreshWeather extends TripWeatherNotifier {
  @override
  Future<TripWeatherState> build(String tripId) async => TripWeatherReady(
    TripWeather(
      signature: 's',
      fetchedAt: DateTime.now(),
      stops: [
        StopWeather(
          name: 'Milano',
          from: DateTime.now(),
          to: DateTime.now().add(const Duration(days: 2)),
          source: WeatherSource.forecast,
          tempMin: 8,
          tempMax: 15,
        ),
      ],
    ),
  );

  @override
  Future<bool> refresh() async => false;
}

void main() {
  Future<List<String>> pump(WidgetTester tester, TripModel trip) async {
    final reads = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripWeatherNotifierProvider(
            trip.id,
          ).overrideWith(() => _FakeWeather(reads)),
        ],
        child: MaterialApp(
          home: Scaffold(body: PackWeatherSection(trip: trip)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return reads;
  }

  testWidgets('viaggio finito da un mese: niente meteo e nessuna richiesta', (
    tester,
  ) async {
    final now = DateTime.now();
    final reads = await pump(
      tester,
      _viaggio(
        departure: now.subtract(const Duration(days: 40)),
        returnAt: now.subtract(const Duration(days: 30)),
      ),
    );
    expect(find.byKey(const Key('pack_weather')), findsNothing);
    expect(reads, isEmpty);
  });

  testWidgets('viaggio finito un\'ora fa: già niente meteo', (tester) async {
    final now = DateTime.now();
    final reads = await pump(
      tester,
      _viaggio(
        departure: now.subtract(const Duration(days: 3)),
        returnAt: now.subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.byKey(const Key('pack_weather')), findsNothing);
    expect(reads, isEmpty);
  });

  testWidgets('viaggio in corso: la sezione c\'è', (tester) async {
    final now = DateTime.now();
    final reads = await pump(
      tester,
      _viaggio(
        departure: now.subtract(const Duration(days: 1)),
        returnAt: now.add(const Duration(days: 2)),
      ),
    );
    expect(find.byKey(const Key('pack_weather')), findsOneWidget);
    expect(reads, ['v1']);
  });

  group('con i testi veri', () {
    const it = Locale('it', 'IT');
    const en = Locale('en', 'US');

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
    });

    /// Monta [child] con i dizionari dell'app nella lingua [locale].
    Future<BuildContext> pumpLocalized(
      WidgetTester tester, {
      Widget child = const SizedBox(),
      Locale locale = it,
      List<Override> overrides = const [],
    }) async {
      late BuildContext contesto;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: EasyLocalization(
            supportedLocales: const [it, en],
            path: 'assets/translations',
            assetLoader: MemoryAssetLoader(readAppTranslations()),
            fallbackLocale: en,
            startLocale: locale,
            saveLocale: false,
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: Builder(
                  builder: (context) {
                    contesto = context;
                    return Scaffold(body: child);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return contesto;
    }

    testWidgets('Aggiorna con meteo già aggiornato lo dice', (tester) async {
      final now = DateTime.now();
      final trip = _viaggio(
        departure: now.add(const Duration(days: 1)),
        returnAt: now.add(const Duration(days: 3)),
      );
      await pumpLocalized(
        tester,
        overrides: [
          tripWeatherNotifierProvider(trip.id).overrideWith(_FreshWeather.new),
        ],
        child: PackWeatherSection(trip: trip),
      );

      expect(find.textContaining('aggiornato poco fa'), findsOneWidget);
      expect(find.textContaining('aggiornato alle'), findsNothing);
      await tester.tap(find.byKey(const Key('pack_weather_refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Il meteo è già aggiornato'), findsOneWidget);
    });

    testWidgets('etichette relative in italiano', (tester) async {
      await pumpLocalized(tester);
      final now = DateTime(2026, 10, 28, 15);
      String label(DateTime fetched) =>
          weatherUpdatedLabel(fetched, now: now, locale: 'it_IT');

      expect(
        label(now.subtract(const Duration(minutes: 59))),
        'aggiornato poco fa',
      );
      expect(
        label(now.subtract(const Duration(hours: 1))),
        "aggiornato un'ora fa",
      );
      expect(
        label(now.subtract(const Duration(hours: 3))),
        'aggiornato 3 ore fa',
      );
      expect(label(DateTime(2026, 10, 27, 9)), 'aggiornato ieri');
      expect(label(DateTime(2026, 10, 20, 9)), 'aggiornato il 20 ott');
    });

    testWidgets('etichette relative in inglese', (tester) async {
      await pumpLocalized(tester, locale: en);
      final now = DateTime(2026, 10, 28, 15);
      String label(DateTime fetched) =>
          weatherUpdatedLabel(fetched, now: now, locale: 'en_US');

      expect(
        label(now.subtract(const Duration(minutes: 5))),
        'updated just now',
      );
      expect(
        label(now.subtract(const Duration(hours: 1))),
        'updated an hour ago',
      );
      expect(
        label(now.subtract(const Duration(hours: 3))),
        'updated 3 hours ago',
      );
      expect(label(DateTime(2026, 10, 27, 9)), 'updated yesterday');
    });
  });
}
