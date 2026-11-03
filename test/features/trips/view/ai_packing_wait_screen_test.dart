import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/profile/providers/gpt_usage_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/features/trips/services/pack_trip_timing.dart';
import 'package:pack_log/features/trips/view/ai_packing_wait_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/packlog_gradient.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

const _houseId = 'h1';

final _job = PackTripJob(
  body: const {'house_id': _houseId},
  houseId: _houseId,
  title: 'Islanda e Olanda',
  nights: 8,
);

final _result = AiPackingResult(
  generatedAt: DateTime.utc(2026, 10, 24, 9),
  houseId: _houseId,
  proposal: const [],
  warnings: const [],
  reasons: const [],
);

/// Finto di `PackTripService`: ogni `generate` prende la risposta successiva
/// da [replies], e `cancel` registra solo che è stato chiamato.
class _FakeService extends PackTripService {
  final List<Completer<AiPackingResult>> replies = [];
  final List<String> houseIds = [];
  int generateCalls = 0;
  bool cancelled = false;

  @override
  Future<AiPackingResult> generate(
    Map<String, dynamic> body, {
    required String houseId,
  }) {
    generateCalls++;
    houseIds.add(houseId);
    final reply = Completer<AiPackingResult>();
    replies.add(reply);
    return reply.future;
  }

  @override
  void cancel() => cancelled = true;

  Completer<AiPackingResult> get last => replies.last;
}

/// Cosa è successo al route della pagina d'attesa.
class _Outcome {
  bool popped = false;
  int completions = 0;
  AiPackingResult? result;
}

class _Monitoring extends AppMonitoringService {
  final captured = <Object>[];

  @override
  void captureException(
    Object exception, {
    StackTrace? stackTrace,
    SentryLevel level = SentryLevel.error,
    Map<String, String>? tags,
  }) => captured.add(exception);
}

late _Monitoring _monitoring;
late _FakeService _service;
late _Outcome _outcome;
late int _usageBuilds;

class _Weather extends TripWeatherNotifier {
  _Weather(this.state0);
  final TripWeatherState state0;

  @override
  Future<TripWeatherState> build(String tripId) async => state0;
}

class _Items extends ItemNotifier {
  _Items(this.count);
  final int count;

  @override
  Future<List<ItemModel>> build(String houseId) async => [
    for (var i = 0; i < count; i++)
      ItemModel(
        id: 'i$i',
        houseId: houseId,
        name: 'Capo $i',
        category: ItemCategory.vestiti,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
}

TripWeather _meteo({double rain = 0}) => TripWeather(
  signature: 's',
  fetchedAt: DateTime(2026, 11, 1),
  stops: [
    StopWeather(
      name: 'Reykjavik',
      from: DateTime(2026, 11, 10),
      to: DateTime(2026, 11, 14),
      source: WeatherSource.climate,
      tempMin: 1.2,
      tempMax: 6.4,
      rainDays: rain,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  PackTripJob? job,
  TripWeather? weather,
  int items = 3,
  bool disableAnimations = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  _service = _FakeService();
  _monitoring = _Monitoring();
  _outcome = _Outcome();
  _usageBuilds = 0;

  final container = ProviderContainer(
    overrides: [
      packTripServiceProvider.overrideWithValue(_service),
      monitoringServiceProvider.overrideWithValue(_monitoring),
      tripWeatherNotifierProvider('trip-1').overrideWith(
        () => _Weather(
          weather == null
              ? const TripWeatherFailed()
              : TripWeatherReady(weather),
        ),
      ),
      itemNotifierProvider(_houseId).overrideWith(() => _Items(items)),
      gptUsageProvider.overrideWith((ref) {
        _usageBuilds++;
        return GptUsageModel(usageCount: 0, usageCap: 30);
      }),
    ],
  );
  // Ascolto la quota: così `invalidate` la ricostruisce e lo si vede.
  container.listen(gptUsageProvider, (_, _) {}, fireImmediately: true);
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      // Radice sotto la casa: un secondo pop della casa si vede (compare la
      // radice) invece di restare silenzioso.
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('RADICE'))),
        routes: [
          GoRoute(
            path: 'home',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await context.push<AiPackingResult>(
                      '/trips/trip-1/ai-packing',
                      extra: job ?? _job,
                    );
                    _outcome
                      ..popped = true
                      ..completions += 1
                      ..result = result;
                  },
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/trips/:id/ai-packing',
        builder: (context, state) => AiPackingWaitScreen(
          tripId: state.pathParameters['id']!,
          job: state.extra! as PackTripJob,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(body: Text('PROFILO')),
      ),
      GoRoute(
        path: '/houses/:id',
        builder: (context, state) =>
            Scaffold(body: Text('CASA ${state.pathParameters['id']}')),
      ),
    ],
  );

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp.router(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: child!,
            ),
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('apri'));
  // Niente pumpAndSettle: lo spinner dell'attesa non si ferma mai.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _text(String text) => find.text(text);

/// Lascia finire la transizione di uscita: lo spinner non si ferma mai, quindi
/// niente pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Lascia passare i minimi dei passi e il passaggio alla valigia. Niente
/// pumpAndSettle: il bordo gira per sempre.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUp(caricaCatalogoDelRepo);

  group('attesa', () {
    testWidgets(
      'la scintilla respira e i tre passi stanno nel bordo che gira',
      (tester) async {
        await _pump(tester);

        final sparkle = tester.widget<PackLogSparkle>(
          find.byType(PackLogSparkle),
        );
        expect(sparkle.breathing, isTrue);
        final border = tester.widget<PackLogGradientBorder>(
          find.byType(PackLogGradientBorder),
        );
        expect(border.loops, -1);
        expect(
          find.descendant(
            of: find.byType(PackLogGradientBorder),
            matching: find.text('Scelgo dal tuo armadio'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(PackLogGradientBorder),
            matching: find.text('Preparo la valigia'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('mostra titolo, tappe e durata', (tester) async {
      await _pump(tester);

      expect(_text('Preparo la valigia'), findsOneWidget);
      expect(_text('Islanda e Olanda · 8 notti'), findsOneWidget);
      expect(_text('Guardo il meteo di Islanda e Olanda'), findsOneWidget);
      expect(_text('Scelgo dal tuo armadio'), findsOneWidget);
      expect(_text('Controllo cosa manca'), findsOneWidget);
      expect(
        _text('Di solito ci vogliono una decina di secondi.'),
        findsOneWidget,
      );
      expect(_text('Annulla'), findsOneWidget);
      expect(_service.generateCalls, 1);
      expect(_service.houseIds, [_houseId]);
    });

    testWidgets('i passi avanzano a un terzo del tempo medio (10 s)', (
      tester,
    ) async {
      await _pump(tester);

      // Il puntino che lampeggia sta sul passo in corso; ce n'è uno solo.
      String blinkingStep() {
        final row = find.ancestor(
          of: find.byKey(const Key('ai_wait_blinking_dot')),
          matching: find.byType(Row),
        );
        return tester
            .widget<Text>(
              find.descendant(of: row.first, matching: find.byType(Text)),
            )
            .data!;
      }

      expect(find.byKey(const Key('ai_wait_blinking_dot')), findsOneWidget);
      expect(blinkingStep(), 'Guardo il meteo di Islanda e Olanda');

      // Il _pump ha già fatto passare mezzo secondo.
      await tester.pump(const Duration(milliseconds: 2832));
      expect(blinkingStep(), 'Guardo il meteo di Islanda e Olanda');
      await tester.pump(const Duration(milliseconds: 2));
      expect(blinkingStep(), 'Scelgo dal tuo armadio');

      await tester.pump(const Duration(milliseconds: 3331));
      expect(blinkingStep(), 'Scelgo dal tuo armadio');
      await tester.pump(const Duration(milliseconds: 1));
      expect(blinkingStep(), 'Controllo cosa manca');
      // Niente rotellina: l'avanzamento lo dice il puntino.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      _service.last.complete(_result);
      await _finish(tester);
    });

    testWidgets(
      'risposta: la route restituisce il risultato e invalida la quota',
      (tester) async {
        await _pump(tester);
        expect(_usageBuilds, 1);

        _service.last.complete(_result);
        await _finish(tester);

        expect(_outcome.popped, isTrue);
        expect(_outcome.result, same(_result));
        expect(_usageBuilds, 2);
        expect(_text('Preparo la valigia'), findsNothing);
      },
    );

    testWidgets('Annulla chiama cancel e torna indietro con null', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Annulla'));
      await _settle(tester);

      expect(_service.cancelled, isTrue);
      expect(_outcome.popped, isTrue);
      expect(_outcome.result, isNull);
      expect(_text('Preparo la valigia'), findsNothing);
      expect(_text('Non è stato possibile preparare la valigia'), findsNothing);
    });
  });

  group('racconto dei passi', () {
    Finder pop() => find.text('Preparo la valigia');

    testWidgets('il tempo imparato sposta i passi (T = 30 s)', (tester) async {
      await _pump(
        tester,
        prefs: {
          'pack_trip_avg_ms': ['30000'],
        },
      );
      await tester.pump(const Duration(milliseconds: 9490));
      expect(find.byKey(const Key('ai_wait_check')), findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const Key('ai_wait_check')), findsOneWidget);
      _service.last.complete(_result);
      await _finish(tester);
    });

    testWidgets('a un terzo del tempo il passo mostra la riga col dato vero', (
      tester,
    ) async {
      await _pump(tester, weather: _meteo(rain: 2), items: 12);
      expect(find.text('1–6°, 2 giorni di pioggia'), findsNothing);
      await tester.pump(const Duration(milliseconds: 3400));
      expect(find.text('1–6°, 2 giorni di pioggia'), findsOneWidget);
      expect(find.text('12 capi guardati'), findsNothing);
      await tester.pump(const Duration(milliseconds: 3400));
      expect(find.text('12 capi guardati'), findsOneWidget);
      _service.last.complete(_result);
      await _finish(tester);
    });

    testWidgets('armadio vuoto e meteo senza pioggia', (tester) async {
      await _pump(tester, weather: _meteo(), items: 0);
      await tester.pump(const Duration(milliseconds: 7000));
      expect(find.text('1–6°'), findsOneWidget);
      expect(find.text('Armadio vuoto: preparo le proposte'), findsOneWidget);
      _service.last.complete(_result);
      await _finish(tester);
    });

    testWidgets('niente riga quando il dato manca', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 3400));
      // Meteo non disponibile: il passo è chiuso ma senza riga.
      expect(find.byKey(const Key('ai_wait_check')), findsOneWidget);
      expect(find.textContaining('°'), findsNothing);
      _service.last.complete(_result);
      await _finish(tester);
    });

    testWidgets('la riga dell\'ultimo passo arriva con la valigia', (
      tester,
    ) async {
      await _pump(
        tester,
        job: PackTripJob(
          body: const {
            'trip': {
              'attivita': ['trekking'],
            },
          },
          houseId: _houseId,
          title: 'Islanda e Olanda',
          nights: 8,
        ),
      );
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Trekking, 8 notti'), findsNothing);
      _service.last.complete(_result);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Trekking, 8 notti'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('arrivo subito: i minimi si rispettano, poi si esce', (
      tester,
    ) async {
      await _pump(tester);
      _service.last.complete(_result);
      // 0,5 s già passati nel pump: servono 1 s + 0,8 + 1 + 0,8 + 1 + 0,8 s
      // dall'inizio, poi i 300 ms del passaggio.
      await tester.pump(const Duration(milliseconds: 4900));
      expect(_outcome.popped, isFalse);
      expect(pop(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('ai_wait_check')), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_outcome.popped, isFalse);
      await _finish(tester);
      expect(_outcome.result, same(_result));
    });

    testWidgets('senza animazioni la valigia si apre subito', (tester) async {
      await _pump(tester, disableAnimations: true);
      _service.last.complete(_result);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_outcome.popped, isTrue);
      expect(_outcome.result, same(_result));
    });

    testWidgets('a valigia arrivata Annulla sfuma e non si tocca', (
      tester,
    ) async {
      await _pump(tester);
      double opacity() => tester
          .widget<AnimatedOpacity>(find.byKey(const Key('ai_wait_cancel')))
          .opacity;
      expect(opacity(), 1);
      _service.last.complete(_result);
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 0);
      await tester.tap(find.text('Annulla'), warnIfMissed: false);
      await tester.pump();
      expect(_service.cancelled, isFalse);
      await _finish(tester);
      expect(_outcome.result, same(_result));
    });

    testWidgets('Annulla durante il racconto non fa niente', (tester) async {
      await _pump(tester);
      _service.last.complete(_result);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Annulla'));
      await tester.pump();
      expect(_service.cancelled, isFalse);
      await _finish(tester);
      expect(_outcome.result, same(_result));
    });
  });

  group('tempo medio', () {
    testWidgets('si aggiorna solo con una generazione riuscita', (
      tester,
    ) async {
      await _pump(
        tester,
        prefs: {
          'pack_trip_avg_ms': ['10000'],
        },
      );
      _service.last.completeError(const PackTripException('rete'));
      await _settle(tester);
      expect(await PackTripTiming.load(), 10000);

      await tester.tap(find.text('Riprova'));
      await tester.pump();
      _service.last.complete(_result);
      await _finish(tester);
      // Il tempo vero del test è quasi zero: la stima scende al minimo.
      expect(await PackTripTiming.load(), lessThan(10000));
    });

    testWidgets('annullare non lo aggiorna', (tester) async {
      await _pump(
        tester,
        prefs: {
          'pack_trip_avg_ms': ['10000'],
        },
      );
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(await PackTripTiming.load(), 10000);
    });
  });

  group('errori', () {
    testWidgets('crediti finiti: rimanda al Profilo', (tester) async {
      await _pump(tester);
      _service.last.completeError(const PackTripCreditsException());
      await _settle(tester);

      expect(_text('Hai finito i crediti AI'), findsOneWidget);
      expect(_usageBuilds, 2);
      expect(find.byType(DsButton), findsOneWidget);

      await tester.tap(find.text('Vai al Profilo'));
      await tester.pumpAndSettle();
      expect(_text('PROFILO'), findsOneWidget);
    });

    testWidgets('armadio vuoto: porta alla casa', (tester) async {
      await _pump(tester);
      _service.last.completeError(const PackTripEmptyWardrobeException());
      await _settle(tester);

      expect(_text('Questa casa non ha vestiti'), findsOneWidget);

      await tester.tap(find.text('Aggiungi vestiti'));
      await tester.pumpAndSettle();
      expect(_text('CASA h1'), findsOneWidget);
    });

    testWidgets('armadio troppo grande: dice il massimo e chiude', (
      tester,
    ) async {
      await _pump(tester);
      _service.last.completeError(const PackTripWardrobeTooLargeException());
      await _settle(tester);

      expect(_text("L'armadio è troppo grande"), findsOneWidget);
      expect(find.textContaining('400'), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);

      await tester.tap(find.text('Chiudi'));
      await _settle(tester);

      expect(_outcome.popped, isTrue);
      expect(_outcome.result, isNull);
    });

    testWidgets('senza rete: dice che sei offline e non segnala', (
      tester,
    ) async {
      await _pump(tester);
      _service.last.completeError(const PackTripNetworkException('rete'));
      await _settle(tester);

      expect(
        _text('Non è stato possibile preparare la valigia'),
        findsOneWidget,
      );
      expect(
        _text('Sei offline. Riprova quando torni in rete.'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Chiudi'), findsOneWidget);
      expect(_monitoring.captured, isEmpty);
    });

    testWidgets('problema del server: testo dedicato e lo segnala', (
      tester,
    ) async {
      await _pump(tester);
      _service.last.completeError(const PackTripException('HTTP 502'));
      await _settle(tester);

      expect(
        _text('Non sono riuscito a preparare la valigia. Riprova tra poco.'),
        findsOneWidget,
      );
      expect(find.textContaining('connessione'), findsNothing);
      expect(find.textContaining('offline'), findsNothing);
      expect(find.textContaining('502'), findsNothing);
      expect(_monitoring.captured, hasLength(1));
    });

    testWidgets('crediti finiti: nessuna segnalazione', (tester) async {
      await _pump(tester);
      _service.last.completeError(const PackTripCreditsException());
      await _settle(tester);

      expect(_text('Hai finito i crediti AI'), findsOneWidget);
      expect(_monitoring.captured, isEmpty);
    });

    testWidgets('errore generico: Riprova richiama generate', (tester) async {
      await _pump(tester);
      _service.last.completeError(const PackTripException('HTTP 502'));
      await _settle(tester);

      expect(
        _text('Non è stato possibile preparare la valigia'),
        findsOneWidget,
      );
      expect(_service.generateCalls, 1);

      await tester.tap(find.text('Riprova'));
      await tester.pump();

      expect(_service.generateCalls, 2);
      expect(_text('Preparo la valigia'), findsOneWidget);

      _service.last.complete(_result);
      await _finish(tester);

      expect(_outcome.result, same(_result));
    });

    testWidgets('errore generico: Chiudi esce senza risultato', (tester) async {
      await _pump(tester);
      _service.last.completeError(const PackTripException('rete'));
      await _settle(tester);

      await tester.tap(find.text('Chiudi'));
      await _settle(tester);

      expect(_outcome.popped, isTrue);
      expect(_outcome.result, isNull);
    });
  });

  group('una sola uscita', () {
    testWidgets('dopo il successo, Annulla non chiude la pagina chiamante', (
      tester,
    ) async {
      await _pump(tester);
      _service.last.complete(_result);
      // Un frame solo: la pagina d'attesa è ancora in uscita. Flutter non
      // consegna tocchi a una route in uscita, quindi si richiama direttamente
      // il callback di Annulla, come farebbe un tocco arrivato prima.
      await tester.pump();
      final annulla = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Annulla'))
          .onPressed!;
      annulla();
      await _finish(tester);

      expect(_outcome.completions, 1);
      expect(_outcome.result, same(_result));
      expect(_service.cancelled, isFalse);
      expect(find.text('RADICE'), findsNothing);
      expect(find.text('apri'), findsOneWidget);
    });

    testWidgets('due Chiudi di fila chiudono una sola volta', (tester) async {
      await _pump(tester);
      _service.last.completeError(const PackTripWardrobeTooLargeException());
      await _settle(tester);

      // Due chiamate dello stesso callback, come due tocchi ravvicinati.
      final chiudi = tester.widget<DsButton>(find.byType(DsButton)).onPressed!;
      chiudi();
      chiudi();
      await _settle(tester);

      expect(_outcome.completions, 1);
      expect(_outcome.result, isNull);
      expect(find.text('RADICE'), findsNothing);
      expect(find.text('apri'), findsOneWidget);
    });
  });
}
