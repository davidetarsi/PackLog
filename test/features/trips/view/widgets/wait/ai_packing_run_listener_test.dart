import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/core/routing/app_router.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/pack_trip_job.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/services/ai_failure_message.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/features/trips/view/widgets/wait/ai_packing_run_listener.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/memory_asset_loader.dart';

/// Il lavoro AI finto: lo stato lo decide il test; conta gli azzeramenti.
class _FakeRun extends AiPackingRun {
  int clears = 0;
  int retries = 0;

  @override
  Future<void> retry() async => retries++;

  void emit(AiPackingRunState next) => state = next;

  @override
  AiPackingRunState build() => const AiRunIdle();

  @override
  void clear() {
    clears++;
    super.clear();
  }
}

final _request = AiPackingRequest(
  trip: TripModel(
    id: 'trip-1',
    name: 'Islanda',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  isNew: false,
  setup: const AiPackingSetup(houseId: 'h1'),
  job: PackTripJob(
    body: const {},
    houseId: 'h1',
    title: 'Islanda e Olanda',
    nights: 8,
  ),
);

late _FakeRun _run;
late ProviderContainer _container;
late List<String> _visited;

Future<void> _pump(WidgetTester tester, {String start = '/'}) async {
  SharedPreferences.setMockInitialValues({});
  _run = _FakeRun();
  _visited = [];
  late GoRouter router;
  router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/new-trip',
        builder: (context, state) =>
            const Scaffold(body: Text('NUOVO VIAGGIO')),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) {
          _visited.add(state.uri.toString());
          return const Scaffold(body: Text('DETTAGLIO'));
        },
      ),
    ],
  );
  _container = ProviderContainer(
    overrides: [
      aiPackingRunProvider.overrideWith(() => _run),
      appRouterProvider.overrideWithValue(router),
    ],
  );
  addTearDown(_container.dispose);
  _container.read(aiPackingRunProvider);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp.router(
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: router,
            builder: (context, child) => AiPackingRunListener(child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _running() => _run.emit(AiRunRunning(_request));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('AiPackingRunListener', () {
    testWidgets('done_while_detached_shows_open_snackbar', (tester) async {
      await _pump(tester);
      _running();
      await tester.pump();

      _run.emit(const AiRunDone('trip-1', itemsError: false));
      await tester.pumpAndSettle();

      expect(find.text('Valigia pronta per Islanda e Olanda'), findsOneWidget);
      expect(find.text('Apri'), findsOneWidget);
      expect(_run.clears, 1);
      expect(_container.read(aiPackingRunProvider), isA<AiRunIdle>());
      expect(find.text('HOME'), findsOneWidget);

      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();

      expect(find.text('DETTAGLIO'), findsOneWidget);
      expect(_visited, ['/trips/trip-1?review=1']);
    });

    testWidgets('done_while_attached_shows_nothing', (tester) async {
      await _pump(tester);
      _run.attach();
      _running();
      await tester.pump();

      _run.emit(const AiRunDone('trip-1', itemsError: false));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(_run.clears, 0);
      expect(_container.read(aiPackingRunProvider), isA<AiRunDone>());
    });

    testWidgets('failure_while_detached_shows_error', (tester) async {
      await _pump(tester);
      _running();
      await tester.pump();

      _run.emit(AiRunFailed(_request, const PackTripException('HTTP 502')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Non sono riuscito a preparare la valigia. Nessun credito è stato scalato.',
        ),
        findsOneWidget,
      );
      expect(_run.clears, 1);
    });

    testWidgets('save_failure_while_detached_offers_retry', (tester) async {
      await _pump(tester);
      _running();
      await tester.pump();

      _run.emit(AiRunFailed(_request, StateError('db'), saveOnly: true));
      await tester.pumpAndSettle();

      expect(
        find.text('Non sono riuscito a salvare la valigia.'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
      // La valigia già pagata non si perde: niente clear().
      expect(_run.clears, 0);

      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(_run.retries, 1);
      expect(_run.clears, 0);
    });

    testWidgets('ignored_retry_snackbar_clears', (tester) async {
      await _pump(tester);
      _running();
      await tester.pump();
      _run.emit(AiRunFailed(_request, StateError('db'), saveOnly: true));
      await tester.pumpAndSettle();
      expect(_run.clears, 0);

      ScaffoldMessenger.of(
        tester.element(find.text('HOME')),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      expect(_run.retries, 0);
      expect(_run.clears, 1);
    });

    testWidgets('failure_while_attached_shows_nothing', (tester) async {
      await _pump(tester);
      _run.attach();
      _running();
      await tester.pump();

      _run.emit(AiRunFailed(_request, const PackTripException('HTTP 502')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(_run.clears, 0);
    });

    testWidgets('items_error_shows_its_message_then_the_ready_one', (
      tester,
    ) async {
      await _pump(tester);
      _running();
      await tester.pump();

      _run.emit(const AiRunDone('trip-1', itemsError: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(
          'Non è stato possibile leggere gli oggetti della casa: la proposta è salvata, ma la valigia non è cambiata.',
        ),
        findsOneWidget,
      );

      // Poi compare quello con "Apri".
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Valigia pronta per Islanda e Olanda'), findsOneWidget);
      expect(find.text('Apri'), findsOneWidget);
    });

    testWidgets('arrival_during_other_new_trip_does_not_navigate', (
      tester,
    ) async {
      await _pump(tester, start: '/new-trip');
      _running();
      await tester.pump();

      _run.emit(const AiRunDone('trip-1', itemsError: false));
      await tester.pumpAndSettle();

      expect(find.text('NUOVO VIAGGIO'), findsOneWidget);
      expect(find.text('DETTAGLIO'), findsNothing);
      expect(_visited, isEmpty);
      expect(find.text('Valigia pronta per Islanda e Olanda'), findsOneWidget);
    });
  });

  group('aiFailureMessageKey', () {
    test('server_error_says_no_credit', () {
      expect(
        aiFailureMessageKey(const PackTripException('HTTP 502')),
        'trips.ai.failed_no_credit',
      );
      expect(
        aiFailureMessageKey(const PackTripCreditsException()),
        'trips.ai.failed_no_credit',
      );
    });

    test('save_error_is_not_no_credit', () {
      expect(aiFailureMessageKey(StateError('boh')), 'trips.ai.failed_save');
      expect(aiFailureMessageKey(Exception('db')), 'trips.ai.failed_save');
    });

    test('network_error_is_generic', () {
      expect(
        aiFailureMessageKey(const PackTripNetworkException('rete')),
        'trips.ai.failed_network',
      );
    });
  });
}
