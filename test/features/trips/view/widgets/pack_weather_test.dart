import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_weather.dart';
import 'package:pack_log/shared/widgets/packlog_gradient.dart';

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

TripWeather _meteo(WeatherSource source, {DateTime? fetchedAt}) => TripWeather(
  signature: 's',
  fetchedAt: fetchedAt ?? DateTime.now(),
  stops: [
    StopWeather(
      name: 'Seul',
      from: DateTime.now(),
      to: DateTime.now().add(const Duration(days: 2)),
      source: source,
      years: source == WeatherSource.climate ? 5 : null,
      tempMin: -7,
      tempMax: 1,
    ),
  ],
);

/// Meteo pronto subito, con la fonte data.
class _ReadyWeather extends TripWeatherNotifier {
  _ReadyWeather(this.source);
  final WeatherSource source;

  @override
  Future<TripWeatherState> build(String tripId) async => TripWeatherReady(
    // Preso un'ora fa: è la copia in cache.
    _meteo(
      source,
      fetchedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  );
}

/// Meteo con uno stato fisso.
class _FixedWeather extends TripWeatherNotifier {
  _FixedWeather(this.fixed);
  final TripWeatherState fixed;

  @override
  Future<TripWeatherState> build(String tripId) async => fixed;
}

/// Meteo che arriva quando il test completa [reply].
class _SlowWeather extends TripWeatherNotifier {
  _SlowWeather(this.reply);
  final Completer<TripWeatherState> reply;

  @override
  Future<TripWeatherState> build(String tripId) => reply.future;
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
      ProviderContainer? container,
    }) async {
      late BuildContext contesto;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container ?? ProviderContainer(overrides: overrides),
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

    group('gradiente PackLog', () {
      late TripModel trip;

      setUp(() {
        final now = DateTime.now();
        trip = _viaggio(
          departure: now.add(const Duration(days: 1)),
          returnAt: now.add(const Duration(days: 3)),
        );
      });

      PackLogGradientBorder border(WidgetTester tester) => tester
          .widget<PackLogGradientBorder>(find.byType(PackLogGradientBorder));

      testWidgets('dal clima: "Stima" con la scintilla', (tester) async {
        await pumpLocalized(
          tester,
          overrides: [
            tripWeatherNotifierProvider(
              trip.id,
            ).overrideWith(() => _ReadyWeather(WeatherSource.climate)),
          ],
          child: PackWeatherSection(trip: trip),
        );
        expect(find.text('Stima'), findsOneWidget);
        expect(find.text('Previsione'), findsNothing);
        expect(find.byType(PackLogSparkle), findsOneWidget);
        expect(find.byType(PackLogGradientBorder), findsOneWidget);
      });

      testWidgets('la stima si apre solo se ha il giorno per giorno', (
        tester,
      ) async {
        Future<void> pumpStop(StopWeather stop) => pumpLocalized(
          tester,
          overrides: [
            tripWeatherNotifierProvider(trip.id).overrideWith(
              () => _FixedWeather(
                TripWeatherReady(
                  TripWeather(
                    signature: 's',
                    fetchedAt: DateTime.now(),
                    stops: [stop],
                  ),
                ),
              ),
            ),
          ],
          child: PackWeatherSection(trip: trip),
        );
        final base = _meteo(WeatherSource.climate).stops.single;

        await pumpStop(base);
        expect(find.byIcon(Icons.chevron_right), findsNothing);

        await pumpStop(
          StopWeather(
            name: base.name,
            from: base.from,
            to: base.to,
            source: base.source,
            years: base.years,
            tempMin: base.tempMin,
            tempMax: base.tempMax,
            historicalDays: [
              HistoricalDayWeather(date: base.from, dataYears: 5),
            ],
          ),
        );
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('dalla previsione, in inglese: "Forecast"', (tester) async {
        await pumpLocalized(
          tester,
          locale: en,
          overrides: [
            tripWeatherNotifierProvider(
              trip.id,
            ).overrideWith(() => _ReadyWeather(WeatherSource.forecast)),
          ],
          child: PackWeatherSection(trip: trip),
        );
        expect(find.text('Forecast'), findsOneWidget);
        expect(find.text('Estimate'), findsNothing);
      });

      testWidgets('misto (fonti diverse): "Stima"', (tester) async {
        final mixed = TripWeather(
          signature: 's',
          fetchedAt: DateTime.now(),
          stops: [
            _meteo(WeatherSource.forecast).stops.single,
            _meteo(WeatherSource.climate).stops.single,
          ],
        );
        expect(mixed.source, isNull);
        await pumpLocalized(
          tester,
          overrides: [
            tripWeatherNotifierProvider(
              trip.id,
            ).overrideWith(() => _FixedWeather(TripWeatherReady(mixed))),
          ],
          child: PackWeatherSection(trip: trip),
        );
        expect(find.text('Stima'), findsOneWidget);
      });

      testWidgets('dalla previsione: "Previsione"', (tester) async {
        await pumpLocalized(
          tester,
          overrides: [
            tripWeatherNotifierProvider(
              trip.id,
            ).overrideWith(() => _ReadyWeather(WeatherSource.forecast)),
          ],
          child: PackWeatherSection(trip: trip),
        );
        // Il titolo di riga e la riga della fonte dicono "Previsione".
        expect(find.text('Previsione'), findsOneWidget);
        expect(find.text('Stima'), findsNothing);
      });

      testWidgets('aperto con il meteo già pronto: bordo fermo', (
        tester,
      ) async {
        // Il meteo è già in memoria (o in cache) prima che la pagina si apra.
        final container = ProviderContainer(
          overrides: [
            tripWeatherNotifierProvider(
              trip.id,
            ).overrideWith(() => _ReadyWeather(WeatherSource.climate)),
          ],
        );
        addTearDown(container.dispose);
        await container.read(tripWeatherNotifierProvider(trip.id).future);

        await pumpLocalized(
          tester,
          container: container,
          child: PackWeatherSection(trip: trip),
        );
        expect(border(tester).loops, 0);
      });

      /// Monta la sezione con il meteo che arriva quando si completa [reply].
      Future<void> pumpSlow(
        WidgetTester tester,
        Completer<TripWeatherState> reply,
      ) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripWeatherNotifierProvider(
                trip.id,
              ).overrideWith(() => _SlowWeather(reply)),
            ],
            child: EasyLocalization(
              supportedLocales: const [it, en],
              path: 'assets/translations',
              assetLoader: MemoryAssetLoader(readAppTranslations()),
              fallbackLocale: en,
              startLocale: it,
              saveLocale: false,
              child: Builder(
                builder: (context) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: Scaffold(body: PackWeatherSection(trip: trip)),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(PackLogGradientBorder), findsNothing);
      }

      testWidgets('da caricamento a pronto con stima nuova: 2 giri', (
        tester,
      ) async {
        final reply = Completer<TripWeatherState>();
        await pumpSlow(tester, reply);

        // Presa dopo l'apertura della pagina.
        reply.complete(TripWeatherReady(_meteo(WeatherSource.climate)));
        await tester.pump();
        await tester.pump();
        expect(border(tester).loops, 2);
        expect(find.text('Stima'), findsOneWidget);
      });

      testWidgets('da caricamento a pronto con una copia vecchia: fermo', (
        tester,
      ) async {
        final reply = Completer<TripWeatherState>();
        await pumpSlow(tester, reply);

        // La prima lettura passa dal caricamento, ma il meteo è quello in
        // cache, preso prima che la pagina si aprisse.
        reply.complete(
          TripWeatherReady(
            _meteo(
              WeatherSource.climate,
              fetchedAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(border(tester).loops, 0);
        expect(find.text('Stima'), findsOneWidget);
      });
    });

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
