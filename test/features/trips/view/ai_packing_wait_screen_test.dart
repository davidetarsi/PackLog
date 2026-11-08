import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/features/trips/view/ai_packing_wait_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
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

AiPackingRequest _requestFor(PackTripJob job) => AiPackingRequest(
  trip: TripModel(
    id: 'trip-1',
    name: 'Islanda',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  isNew: false,
  setup: const AiPackingSetup(houseId: _houseId),
  job: job,
);

/// Il lavoro AI finto: lo stato lo decide il test; registra le chiamate.
class _FakeRun extends AiPackingRun {
  int attaches = 0;
  int detaches = 0;
  int clears = 0;
  int retries = 0;

  void emit(AiPackingRunState next) => state = next;

  @override
  AiPackingRunState build() => const AiRunIdle();

  @override
  void attach() => attaches++;

  @override
  void detach() => detaches++;

  @override
  void clear() {
    clears++;
    state = const AiRunIdle();
  }

  @override
  Future<void> retry() async {
    retries++;
    final current = state;
    if (current is AiRunFailed) state = AiRunRunning(current.request);
  }
}

late _FakeRun _run;
late AiPackingRequest _request;

/// Dove è arrivato il router.
late List<String> _visited;

late ProviderContainer _container;

class _Weather extends TripWeatherNotifier {
  _Weather(this.state0);
  final TripWeatherState state0;

  @override
  Future<TripWeatherState> build(String tripId) async => state0;
}

/// Meteo che arriva quando lo decide il test.
class _LateWeather extends TripWeatherNotifier {
  _LateWeather(this.arrival);
  final Completer<TripWeatherState> arrival;

  @override
  Future<TripWeatherState> build(String tripId) => arrival.future;
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

/// Apre la pagina d'attesa sopra "home" con un lavoro in corso.
Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  PackTripJob? job,
  TripWeather? weather,
  Completer<TripWeatherState>? lateWeather,
  int items = 3,
  bool disableAnimations = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  _run = _FakeRun();
  _request = _requestFor(job ?? _job);
  _visited = [];

  final container = ProviderContainer(
    overrides: [
      aiPackingRunProvider.overrideWith(() => _run),
      tripWeatherNotifierProvider('trip-1').overrideWith(
        () => lateWeather != null
            ? _LateWeather(lateWeather)
            : _Weather(
                weather == null
                    ? const TripWeatherFailed()
                    : TripWeatherReady(weather),
              ),
      ),
      itemNotifierProvider(_houseId).overrideWith(() => _Items(items)),
    ],
  );
  addTearDown(container.dispose);
  _container = container;
  // Il notifier si inizializza alla prima lettura.
  container.read(aiPackingRunProvider);

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
                  onPressed: () {
                    _run.emit(AiRunRunning(_request));
                    context.push('/ai-packing');
                  },
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/ai-packing',
        builder: (context, state) => const AiPackingWaitScreen(),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) {
          _visited.add(state.uri.toString());
          return const Scaffold(body: Text('DETTAGLIO'));
        },
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
  // Niente pumpAndSettle: il bordo dell'attesa non si ferma mai.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _text(String text) => find.text(text);

/// La valigia è arrivata, salvata sul viaggio trip-1.
void _arrive() => _run.emit(const AiRunDone('trip-1', itemsError: false));

void _fail(Object error) => _run.emit(AiRunFailed(_request, error));

/// Lascia finire una transizione: il bordo gira per sempre, quindi niente
/// pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Lascia passare i minimi dei passi e il passaggio alla valigia.
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
      },
    );

    testWidgets('mostra titolo, tappe e durata e si attacca', (tester) async {
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
      expect(_run.attaches, 1);
    });

    testWidgets('no_cancel_button', (tester) async {
      await _pump(tester);

      expect(find.text('Annulla'), findsNothing);
      expect(find.byKey(const Key('ai_wait_cancel')), findsNothing);
    });

    testWidgets('shows_stay_line', (tester) async {
      await _pump(tester);

      expect(
        _text(
          'Resta qui mentre prepariamo la valigia: non chiudere PackLog e non aprire altre app.',
        ),
        findsOneWidget,
      );
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

      _arrive();
      await _finish(tester);
    });

    testWidgets('back_detaches_and_keeps_running', (tester) async {
      await _pump(tester);

      await tester.binding.handlePopRoute();
      await _settle(tester);

      expect(_run.detaches, greaterThanOrEqualTo(1));
      expect(_run.clears, 0);
      expect(_container.read(aiPackingRunProvider), isA<AiRunRunning>());
      expect(find.text('apri'), findsOneWidget);
      expect(_text('Preparo la valigia'), findsNothing);
    });

    testWidgets('arrival_while_attached_opens_review', (tester) async {
      await _pump(tester);

      _arrive();
      await _finish(tester);

      expect(_visited, ['/trips/trip-1?review=1']);
      expect(_text('DETTAGLIO'), findsOneWidget);
      expect(_run.clears, 1);
      // `go` sostituisce la pila: la casa e la radice non ci sono più.
      expect(find.text('apri'), findsNothing);
    });

    testWidgets('senza animazioni la valigia si apre subito', (tester) async {
      await _pump(tester, disableAnimations: true);

      _arrive();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(_visited, ['/trips/trip-1?review=1']);
      expect(_run.clears, 1);
    });

    testWidgets('arrivo subito: i minimi si rispettano, poi si esce', (
      tester,
    ) async {
      await _pump(tester);
      _arrive();
      // 0,5 s già passati nel pump: servono 1 s + 0,8 + 1 + 0,8 + 1 + 0,8 s
      // dall'inizio, poi i 300 ms del passaggio.
      await tester.pump(const Duration(milliseconds: 4900));
      expect(_visited, isEmpty);
      expect(_text('Preparo la valigia'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('ai_wait_check')), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_visited, isEmpty);
      await _finish(tester);
      expect(_visited, ['/trips/trip-1?review=1']);
    });

    testWidgets('back_during_handoff_navigates_once', (tester) async {
      await _pump(tester);
      _arrive();
      // In pieno racconto d'arrivo: la valigia è già salvata.
      await tester.pump(const Duration(seconds: 1));

      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await _finish(tester);

      expect(_visited, ['/trips/trip-1?review=1']);
      expect(_run.clears, 1);
      expect(find.text('RADICE'), findsNothing);
    });

    testWidgets('una pagina senza lavoro si chiude da sola', (tester) async {
      await _pump(tester);
      _run.emit(const AiRunIdle());
      await _settle(tester);

      expect(find.text('apri'), findsOneWidget);
      expect(_run.clears, 0);
    });
  });

  group('racconto dei passi', () {
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
      _arrive();
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
      _arrive();
      await _finish(tester);
    });

    testWidgets('il meteo che arriva in ritardo compare con la dissolvenza', (
      tester,
    ) async {
      final arrival = Completer<TripWeatherState>();
      await _pump(tester, lateWeather: arrival);
      await tester.pump(const Duration(milliseconds: 3400));
      expect(find.byKey(const Key('ai_wait_check')), findsOneWidget);
      expect(find.text('1–6°, 2 giorni di pioggia'), findsNothing);
      final result = find.byKey(const Key('ai_wait_result')).first;
      expect(tester.widget<AnimatedOpacity>(result).opacity, 0);

      arrival.complete(TripWeatherReady(_meteo(rain: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('1–6°, 2 giorni di pioggia'), findsOneWidget);
      expect(tester.widget<AnimatedOpacity>(result).opacity, 1);
      await tester.pump(const Duration(milliseconds: 3400));
      expect(find.text('3 capi guardati'), findsOneWidget);
      _arrive();
      await _finish(tester);
    });

    testWidgets('armadio vuoto e meteo senza pioggia', (tester) async {
      await _pump(tester, weather: _meteo(), items: 0);
      await tester.pump(const Duration(milliseconds: 7000));
      expect(find.text('1–6°'), findsOneWidget);
      expect(find.text('Armadio vuoto: preparo le proposte'), findsOneWidget);
      _arrive();
      await _finish(tester);
    });

    testWidgets('niente riga quando il dato manca', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 3400));
      expect(find.byKey(const Key('ai_wait_check')), findsOneWidget);
      expect(find.textContaining('°'), findsNothing);
      _arrive();
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
      _arrive();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Trekking, 8 notti'), findsOneWidget);
      await _finish(tester);
    });
  });

  group('errori', () {
    testWidgets('crediti finiti: rimanda al Profilo', (tester) async {
      await _pump(tester);
      _fail(const PackTripCreditsException());
      await _settle(tester);

      expect(_text('Hai finito i crediti AI'), findsOneWidget);
      expect(find.byType(DsButton), findsOneWidget);

      await tester.tap(find.text('Vai al Profilo'));
      await tester.pumpAndSettle();
      expect(_text('PROFILO'), findsOneWidget);
      expect(_run.clears, 1);
    });

    testWidgets('armadio vuoto: porta alla casa', (tester) async {
      await _pump(tester);
      _fail(const PackTripEmptyWardrobeException());
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
      _fail(const PackTripWardrobeTooLargeException());
      await _settle(tester);

      expect(_text("L'armadio è troppo grande"), findsOneWidget);
      expect(find.textContaining('400'), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);

      await tester.tap(find.text('Chiudi'));
      await _settle(tester);

      expect(_run.clears, 1);
      expect(find.text('apri'), findsOneWidget);
    });

    testWidgets('senza rete: dice che sei offline', (tester) async {
      await _pump(tester);
      _fail(const PackTripNetworkException('rete'));
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
    });

    testWidgets('problema del server: testo dedicato', (tester) async {
      await _pump(tester);
      _fail(const PackTripException('HTTP 502'));
      await _settle(tester);

      expect(
        _text('Non sono riuscito a preparare la valigia. Riprova tra poco.'),
        findsOneWidget,
      );
      expect(find.textContaining('502'), findsNothing);
    });

    testWidgets('failure_retry_and_close', (tester) async {
      await _pump(tester);
      _fail(const PackTripException('HTTP 502'));
      await _settle(tester);

      await tester.tap(find.text('Riprova'));
      await tester.pump();
      expect(_run.retries, 1);
      // Il lavoro riparte: di nuovo l'attesa, coi passi da capo.
      expect(_text('Preparo la valigia'), findsOneWidget);
      expect(_text('Guardo il meteo di Islanda e Olanda'), findsOneWidget);

      _fail(const PackTripException('HTTP 502'));
      await _settle(tester);
      await tester.tap(find.text('Chiudi'));
      await _settle(tester);

      expect(_run.clears, 1);
      expect(find.text('apri'), findsOneWidget);
      expect(find.text('RADICE'), findsNothing);
    });

    testWidgets('indietro in errore chiude e azzera', (tester) async {
      await _pump(tester);
      _fail(const PackTripException('rete'));
      await _settle(tester);

      await tester.binding.handlePopRoute();
      await _settle(tester);

      expect(_run.clears, 1);
      expect(find.text('apri'), findsOneWidget);
    });
  });

  group('una sola uscita', () {
    testWidgets('due Chiudi di fila chiudono una sola volta', (tester) async {
      await _pump(tester);
      _fail(const PackTripWardrobeTooLargeException());
      await _settle(tester);

      // Due chiamate dello stesso callback, come due tocchi ravvicinati.
      final chiudi = tester.widget<DsButton>(find.byType(DsButton)).onPressed!;
      chiudi();
      chiudi();
      await _settle(tester);

      expect(_run.clears, 1);
      expect(find.text('RADICE'), findsNothing);
      expect(find.text('apri'), findsOneWidget);
    });
  });
}
