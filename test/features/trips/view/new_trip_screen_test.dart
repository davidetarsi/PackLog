import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/pack_trip_job.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/new_trip_screen.dart';
import 'package:pack_log/features/trips/view/widgets/place_search.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/model/location_type.dart';
import 'package:pack_log/shared/services/location_search_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockRawAnalytics extends Mock implements AppAnalyticsService {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockLocationSearchService extends Mock implements LocationSearchService {}

class _MockLuggageRepository extends Mock implements LuggageRepository {}

/// Il lavoro AI finto: registra le richieste e resta in corso.
class _FakeRun extends AiPackingRun {
  final requests = <AiPackingRequest>[];

  /// `start` solleva: il lancio dell'AI fallisce.
  bool failStart = false;

  @override
  AiPackingRunState build() => const AiRunIdle();

  @override
  bool start(AiPackingRequest request) {
    if (failStart) throw StateError('start fallito');
    if (state is AiRunRunning) return false;
    requests.add(request);
    state = AiRunRunning(request);
    return true;
  }
}

class _Kits extends KitNotifier {
  @override
  Future<List<KitModel>> build(String houseId) async => const [];
}

/// Onboarding in memoria: il passo salvato si legge dopo il test.
class _MemoryOnboardingRepository implements IOnboardingRepository {
  OnboardingStep step = OnboardingStep.firstTrip;

  @override
  Future<OnboardingStep> loadStep() async => step;
  @override
  Future<void> saveStep(OnboardingStep value) async => step = value;
  @override
  Future<bool> loadSkippedAi() async => false;
  @override
  Future<void> saveSkippedAi(bool value) async {}
  @override
  Future<bool> loadHasExistingHouses() async => false;
  @override
  Future<void> saveHasExistingHouses(bool value) async {}
  @override
  Future<String?> loadDefaultHouseId() async => null;
  @override
  Future<void> saveDefaultHouseId(String? id) async {}
}

final _houses = [
  HouseModel(
    id: 'h1',
    name: 'Casa Milano',
    isPrimary: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h2',
    name: 'Casa al mare',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h3',
    name: 'Casa in montagna',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

final _places = [
  LocationSuggestionModel(
    placeId: 'p1',
    displayName: 'Marsiglia, Francia',
    name: 'Marsiglia',
    city: 'Marsiglia',
    country: 'Francia',
    lat: 43.3,
    lon: 5.4,
    locationType: LocationType.city,
  ),
];

/// Primo e secondo giorno del mese prossimo: sempre futuri, e il calendario
/// va scorso fino a loro (vedi [_tapDay]).
final _nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
final _departure = DateTime(_nextMonth.year, _nextMonth.month, 10);
final _return = DateTime(_nextMonth.year, _nextMonth.month, 12);

Finder _dayFinder(DateTime day) => find.byKey(
  ValueKey('trip_calendar_day_${DateFormat('yyyy-MM-dd').format(day)}'),
);

/// Scorre il calendario fino al giorno e lo tocca.
Future<void> _tapDay(WidgetTester tester, DateTime day) async {
  final finder = _dayFinder(day);
  await tester.scrollUntilVisible(
    finder,
    50,
    scrollable: find.descendant(
      of: find.byType(TripCalendar),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _placeField => find.descendant(
  of: find.byType(PlaceSearch),
  matching: find.byType(TextField),
);

Finder get _nameField => find.descendant(
  of: find.byKey(const Key('new_trip_name')),
  matching: find.byType(TextField),
);

String _nameText(WidgetTester tester) =>
    tester.widget<TextField>(_nameField).controller!.text;

/// Sceglie una casa dalla ricerca della meta.
Future<void> _pickHouse(WidgetTester tester, String id) async {
  await tester.tap(_placeField);
  await tester.pump();
  await tester.tap(find.byKey(Key('place_search_house_$id')));
  await tester.pumpAndSettle();
}

DateTime _day(int day) => DateTime(_nextMonth.year, _nextMonth.month, day);

/// Il campo place della tappa aperta nel foglio.
Finder get _stopPlaceField => find.descendant(
  of: find.byKey(const Key('stop_sheet_place')),
  matching: find.byType(TextField),
);

/// Aggiunge una tappa in coda dalla sua riga: casa e giorno di fine.
Future<void> _addStop(
  WidgetTester tester, {
  required String houseId,
  required int endDay,
}) async {
  await tester.ensureVisible(find.byKey(const Key('new_trip_add_stop')));
  await tester.tap(find.byKey(const Key('new_trip_add_stop')));
  await tester.pumpAndSettle();
  await tester.tap(_stopPlaceField);
  await tester.pump();
  await tester.tap(find.byKey(Key('place_search_house_$houseId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('stop_sheet_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _day(endDay));
  await tester.tap(find.text('Conferma'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('stop_sheet_save')));
  await tester.pumpAndSettle();
}

/// Cambia la fine della meta: il foglio ha il range completo, quindi il primo
/// tocco riparte dalla partenza e il secondo sceglie il ritorno.
Future<void> _moveDestinationEnd(WidgetTester tester, DateTime end) async {
  await tester.ensureVisible(find.byKey(const Key('new_trip_dates')));
  await tester.tap(find.byKey(const Key('new_trip_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _departure);
  await _tapDay(tester, end);
  await tester.tap(find.text('Conferma date'));
  await tester.pumpAndSettle();
}

/// Sceglie le date di andata e ritorno dal foglio "Quando?".
Future<void> _pickDates(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('new_trip_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _departure);
  await _tapDay(tester, _return);
  await tester.tap(find.text('Conferma date'));
  await tester.pumpAndSettle();
}

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockLocationSearchService locationService;
  late MockTripLifecycleService lifecycle;
  late ProviderContainer container;
  late _MemoryOnboardingRepository onboardingRepo;
  late MockRawAnalytics rawAnalytics;
  late _FakeRun run;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(
      TripModel(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    locationService = MockLocationSearchService();
    lifecycle = MockTripLifecycleService();
    onboardingRepo = _MemoryOnboardingRepository();
    rawAnalytics = MockRawAnalytics();
    when(
      () => rawAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => []);
    when(() => tripRepo.addTrip(any())).thenAnswer((_) async {});
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => _houses);
    when(
      () => locationService.search(any(), lang: any(named: 'lang')),
    ).thenAnswer((_) async => _places);
    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);

    run = _FakeRun();
    final itemRepo = MockItemRepository();
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer((_) async => []);
    final luggageRepo = _MockLuggageRepository();
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => []);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => []);

    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        houseRepositoryProvider.overrideWithValue(houseRepo),
        itemRepositoryProvider.overrideWithValue(itemRepo),
        luggageRepositoryProvider.overrideWithValue(luggageRepo),
        categoryInferServiceProvider.overrideWith(
          (ref) => Completer<CategoryInferService>().future,
        ),
        aiPackingRunProvider.overrideWith(() => run),
        for (final id in ['h1', 'h2', 'h3'])
          kitNotifierProvider(id).overrideWith(_Kits.new),
        coreAnalyticsServiceProvider.overrideWithValue(
          CoreAnalyticsService(rawAnalytics),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
        tripLifecycleServiceProvider.overrideWithValue(lifecycle),
        locationSearchServiceProvider.overrideWithValue(locationService),
        onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
        analyticsServiceProvider.overrideWithValue(rawAnalytics),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Monta la schermata sopra una tab finta "/trips", come dalla tab Viaggi:
  /// il bottone "apri" spinge [open] con `push`, così Indietro ha dove tornare.
  Future<void> pumpScreen(
    WidgetTester tester, {
    String open = '/new-trip',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await container.read(tripNotifierProvider.future);
    await container.read(houseNotifierProvider.future);
    await container.read(postLoginOnboardingProvider.future);

    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/trips',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('trips-tab'),
                Text('focus=${state.uri.queryParameters['focus']}'),
                ElevatedButton(
                  onPressed: () => context.push(open),
                  child: const Text('apri'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                Text(
                  'edit-items ${state.pathParameters['id']} '
                  'from=${state.uri.queryParameters['from']}',
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/ai-packing',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('ai-wait')),
        ),
        GoRoute(
          path: '/new-trip',
          builder: (_, state) => NewTripScreen(
            firstRun: state.uri.queryParameters['first'] == '1',
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-info',
          builder: (_, state) =>
              NewTripScreen(tripId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) => MaterialApp.router(
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  TripModel savedTrip() =>
      verify(() => tripRepo.addTrip(captureAny())).captured.single as TripModel;

  group('NewTripScreen — campi', () {
    testWidgets('"Quando?" è alto come il campo "Dove vai?"', (tester) async {
      await pumpScreen(tester);

      final where = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('new_trip_place_search')),
          matching: find.byType(TextField),
        ),
      );
      final when = tester.getSize(find.byKey(const Key('new_trip_dates')));

      expect(when.height, where.height);
    });

    testWidgets('con la tastiera aperta i bottoni non salgono', (tester) async {
      // Come negli altri form con CTA in fondo (StickyCtaScaffold): la
      // tastiera copre i bottoni invece di spingerli sopra di sé.
      await pumpScreen(tester);
      final before = tester.getTopLeft(
        find.byKey(const Key('new_trip_choose_items')),
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(
        find.byKey(const Key('new_trip_choose_items')),
      );
      expect(after.dy, before.dy);
    });
  });

  group('NewTripScreen — passo 1 con due strade', () {
    Future<void> pickPlace(WidgetTester tester) async {
      await tester.tap(_placeField);
      await tester.pump();
      await tester.enterText(_placeField, 'Mar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location_result_0')));
      await tester.pumpAndSettle();
    }

    /// Conferma il foglio "Valigia con AI" con le risposte di base.
    Future<void> confirmSheet(WidgetTester tester) async {
      for (final label in ['Città e musei', 'Hotel']) {
        final pill = find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.widgetWithText(DsChoicePill, label),
        );
        if (pill.evaluate().isNotEmpty &&
            !tester.widget<DsChoicePill>(pill).selected) {
          final text = find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.text(label),
          );
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          await tester.tap(text);
          await tester.pumpAndSettle();
        }
      }
      final prepare = find.descendant(
        of: find.byType(DsFormSheet),
        matching: find.text('Prepara la valigia'),
      );
      await tester.ensureVisible(prepare);
      await tester.pumpAndSettle();
      await tester.tap(prepare);
      await tester.pumpAndSettle();
    }

    Future<void> fillStep(WidgetTester tester) async {
      caricaCatalogoDelRepo();
      await pickPlace(tester);
      await _pickDates(tester);
    }

    DsButton button(WidgetTester tester, String key) =>
        tester.widget<DsButton>(find.byKey(Key(key)));

    testWidgets('two_buttons_only', (tester) async {
      await pumpScreen(tester);

      final ai = find.byKey(const Key('new_trip_prepare_ai'));
      final choose = find.byKey(const Key('new_trip_choose_items'));
      expect(ai, findsOneWidget);
      expect(choose, findsOneWidget);
      expect(find.text('Prepara la valigia con AI'), findsOneWidget);
      expect(find.text('Scegli tu cosa portare'), findsOneWidget);
      expect(
        button(tester, 'new_trip_prepare_ai').variant,
        DsButtonVariant.primary,
      );
      expect(
        button(tester, 'new_trip_choose_items').variant,
        DsButtonVariant.secondary,
      );
      expect(
        find.descendant(of: ai, matching: find.byIcon(Icons.auto_awesome)),
        findsOneWidget,
      );
      expect(tester.getSize(ai).height, tester.getSize(choose).height);
      expect(tester.getTopLeft(ai).dy, lessThan(tester.getTopLeft(choose).dy));
      for (final gone in [
        'new_trip_next',
        'new_trip_later',
        'new_trip_manual',
      ]) {
        expect(find.byKey(Key(gone)), findsNothing);
      }
      expect(find.text('Prepara la valigia più tardi'), findsNothing);
      expect(find.text('Prepara a mano'), findsNothing);
    });

    testWidgets('edit_shows_save_only', (tester) async {
      final trip = TripModel(
        id: 'trip-1',
        name: 'Toscana',
        departureDateTime: DateTime(2026, 9, 12),
        returnDateTime: DateTime(2026, 9, 20),
        destinationLocation: LocationSuggestionModel(
          placeId: 'p',
          displayName: 'Siena, Italia',
          city: 'Siena',
        ),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);

      await pumpScreen(tester, open: '/trips/trip-1/edit-info');

      expect(find.byKey(const Key('edit_trip_save')), findsOneWidget);
      expect(find.byKey(const Key('new_trip_prepare_ai')), findsNothing);
      expect(find.byKey(const Key('new_trip_choose_items')), findsNothing);
    });

    testWidgets('a modulo vuoto i bottoni sono spenti, poi si accendono', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(button(tester, 'new_trip_prepare_ai').onPressed, isNull);
      expect(button(tester, 'new_trip_choose_items').onPressed, isNull);

      await fillStep(tester);
      expect(button(tester, 'new_trip_prepare_ai').onPressed, isNotNull);
      expect(button(tester, 'new_trip_choose_items').onPressed, isNotNull);
    });

    testWidgets('"Dove vai?" e "Quando?" hanno l\'asterisco, il nome no', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Dove vai? *'), findsOneWidget);
      expect(find.text('Quando? *'), findsOneWidget);
      expect(find.textContaining('Nome del viaggio *'), findsNothing);
    });

    testWidgets('con la tastiera aperta i bottoni non salgono', (tester) async {
      await pumpScreen(tester);
      final key = find.byKey(const Key('new_trip_choose_items'));
      final before = tester.getTopLeft(key);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(key).dy, before.dy);
    });

    testWidgets('ai_does_not_save_trip', (tester) async {
      await pumpScreen(tester);
      await fillStep(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();
      await confirmSheet(tester);

      verifyNever(() => tripRepo.addTrip(any()));
      expect(container.read(tripNotifierProvider).valueOrNull, isEmpty);
      expect(run.requests, hasLength(1));
      final request = run.requests.single;
      expect(request.isNew, isTrue);
      expect(
        request.trip.destinationLocation?.displayName,
        'Marsiglia, Francia',
      );
      expect(request.trip.departureDateTime, _departure);
      expect(request.trip.items, isEmpty);
      expect(find.text('ai-wait'), findsOneWidget);
    });

    testWidgets('sheet_closed_keeps_step_filled', (tester) async {
      await pumpScreen(tester);
      await fillStep(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();
      expect(find.byType(DsFormSheet), findsOneWidget);
      // Tocco fuori dal foglio: si chiude senza confermare.
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();

      expect(find.byType(DsFormSheet), findsNothing);
      expect(run.requests, isEmpty);
      verifyNever(() => tripRepo.addTrip(any()));
      expect(find.byKey(const Key('new_trip_destination')), findsOneWidget);
      expect(find.text('Nuovo viaggio'), findsOneWidget);
      expect(button(tester, 'new_trip_prepare_ai').isLoading, isFalse);
      expect(button(tester, 'new_trip_prepare_ai').onPressed, isNotNull);
    });

    testWidgets('prepare_ai_error_resets_saving', (tester) async {
      await pumpScreen(tester);
      await fillStep(tester);
      run.failStart = true;

      // Il tocco gira in una zona a parte: l'errore del lancio arriva fin lì
      // (non va inghiottito) senza far fallire il test.
      final errors = <Object>[];
      runZonedGuarded(
        button(tester, 'new_trip_prepare_ai').onPressed!,
        (error, _) => errors.add(error),
      );
      await tester.pumpAndSettle();
      await confirmSheet(tester);

      expect(errors, [isA<StateError>()]);
      expect(button(tester, 'new_trip_prepare_ai').isLoading, isFalse);
      expect(button(tester, 'new_trip_prepare_ai').onPressed, isNotNull);
      expect(button(tester, 'new_trip_choose_items').onPressed, isNotNull);
    });

    testWidgets('setup_kept_on_reopen', (tester) async {
      await pumpScreen(tester);
      await fillStep(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();
      await confirmSheet(tester);
      expect(run.requests, hasLength(1));
      expect(run.requests.first.trip.aiSetup, isNull);

      // Errore: il lavoro si chiude e dalla pagina d'attesa si torna al passo 1.
      container.read(aiPackingRunProvider.notifier).clear();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new_trip_prepare_ai')), findsOneWidget);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();
      await confirmSheet(tester);

      expect(run.requests, hasLength(2));
      expect(run.requests[1].trip.aiSetup, run.requests.first.setup);
      // Lo stesso id fra i tentativi.
      expect(run.requests[1].trip.id, run.requests.first.trip.id);
    });

    testWidgets('choose_items_saves_and_opens_pack', (tester) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      final trip = savedTrip();
      expect(trip.destinationHouseId, 'h1');
      expect(trip.departureDateTime, _departure);
      expect(trip.returnDateTime, _return);
      expect(trip.name, 'Casa Milano');
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
      expect(run.requests, isEmpty);
    });

    testWidgets('choose_items_while_ai_running_shows_busy_and_saves_nothing', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      container.read(aiPackingRunProvider);
      run.start(
        AiPackingRequest(
          trip: TripModel(
            id: 'altro',
            name: 'Altro',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          isNew: false,
          setup: const AiPackingSetup(houseId: 'h1'),
          job: PackTripJob(body: {}, houseId: 'h1', title: 'X', nights: 1),
        ),
      );

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      expect(
        find.text('Sto già preparando una valigia: ti avviso quando è pronta.'),
        findsOneWidget,
      );
      verifyNever(() => tripRepo.addTrip(any()));
      expect(find.text('Nuovo viaggio'), findsOneWidget);
    });

    testWidgets('disabled_tap_shows_missing', (tester) async {
      for (final key in ['new_trip_prepare_ai', 'new_trip_choose_items']) {
        await pumpScreen(tester);

        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();

        expect(
          find.text('Scegli dove vai: serve anche per il meteo.'),
          findsOneWidget,
        );
        expect(find.text('Scegli andata e ritorno.'), findsOneWidget);
        verifyNever(() => tripRepo.addTrip(any()));
        expect(run.requests, isEmpty);
        // Si riparte da una pagina nuova.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('doppio tocco su "Scegli tu cosa portare" salva una volta', (
      tester,
    ) async {
      final saving = Completer<void>();
      when(() => tripRepo.addTrip(any())).thenAnswer((_) => saving.future);
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pump();
      saving.complete();
      await tester.pumpAndSettle();

      final trip =
          verify(() => tripRepo.addTrip(captureAny())).captured.single
              as TripModel;
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
    });

    testWidgets('firstRun: titolo "Dove vai?" e due strade', (tester) async {
      await pumpScreen(tester, open: '/new-trip?first=1');

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Dove vai?'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('new_trip_first_close')), findsOneWidget);
      expect(find.byKey(const Key('new_trip_prepare_ai')), findsOneWidget);
      expect(find.byKey(const Key('new_trip_choose_items')), findsOneWidget);
    });

    testWidgets('senza firstRun non c\'è la X e il titolo è "Nuovo viaggio"', (
      tester,
    ) async {
      await pumpScreen(tester, open: '/new-trip');

      expect(find.byKey(const Key('new_trip_first_close')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Nuovo viaggio'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('firstRun: la X salva done e porta a /', (tester) async {
      await pumpScreen(tester, open: '/new-trip?first=1');
      expect(onboardingRepo.step, OnboardingStep.firstTrip);

      await tester.tap(find.byKey(const Key('new_trip_first_close')));
      await tester.pumpAndSettle();

      expect(onboardingRepo.step, OnboardingStep.done);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets(
      'firstRun: "Scegli tu cosa portare" chiude "Dove vai?" (done)',
      (tester) async {
        await pumpScreen(tester, open: '/new-trip?first=1');
        await _pickHouse(tester, 'h1');
        await _pickDates(tester);

        await tester.tap(find.byKey(const Key('new_trip_choose_items')));
        await tester.pumpAndSettle();

        expect(onboardingRepo.step, OnboardingStep.done);
        expect(find.textContaining('edit-items'), findsOneWidget);
      },
    );

    testWidgets('firstRun: la strada AI non chiude "Dove vai?" da sola', (
      tester,
    ) async {
      await pumpScreen(tester, open: '/new-trip?first=1');
      await fillStep(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();
      await confirmSheet(tester);

      // Lo chiude il lavoro quando la valigia arriva (provider finto qui).
      expect(onboardingRepo.step, OnboardingStep.firstTrip);
      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('firstRun: first_trip_started parte una volta', (tester) async {
      await pumpScreen(tester, open: '/new-trip?first=1');
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      verifyNever(
        () => rawAnalytics.logEvent(
          'first_trip_started',
          properties: any(named: 'properties'),
        ),
      );

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      verify(
        () => rawAnalytics.logEvent('first_trip_started', properties: {}),
      ).called(1);
      expect(find.textContaining('from=new'), findsOneWidget);
    });

    testWidgets('senza firstRun first_trip_started non parte e il passo '
        'non cambia', (tester) async {
      await pumpScreen(tester, open: '/new-trip');
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      verifyNever(
        () => rawAnalytics.logEvent(
          'first_trip_started',
          properties: any(named: 'properties'),
        ),
      );
      expect(onboardingRepo.step, OnboardingStep.firstTrip);
    });
  });

  group('NewTripScreen — uscita', () {
    testWidgets(
      'a modulo vuoto il tocco su "Scegli tu cosa portare" mostra i due errori',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.byKey(const Key('new_trip_choose_items')));
        await tester.pumpAndSettle();

        expect(
          find.text('Scegli dove vai: serve anche per il meteo.'),
          findsOneWidget,
        );
        expect(find.text('Scegli andata e ritorno.'), findsOneWidget);
        verifyNever(() => tripRepo.addTrip(any()));
      },
    );

    testWidgets(
      '"Scegli tu cosa portare" salva meta e date e porta a edit-items?from=new',
      (tester) async {
        await pumpScreen(tester);
        await _pickHouse(tester, 'h1');
        await _pickDates(tester);

        await tester.tap(find.byKey(const Key('new_trip_choose_items')));
        await tester.pumpAndSettle();

        final trip = savedTrip();
        expect(trip.destinationHouseId, 'h1');
        expect(trip.departureDateTime, _departure);
        expect(trip.returnDateTime, _return);
        expect(trip.name, 'Casa Milano');
        expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
      },
    );

    testWidgets('scegliere Aereo e Treno salva ["plane","train"]', (
      tester,
    ) async {
      caricaCatalogoDelRepo();
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      expect(find.text('Come ci vai?'), findsOneWidget);
      for (final label in ['Aereo', 'Treno']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      expect(savedTrip().transports, ['plane', 'train']);
    });

    testWidgets('senza scegliere il mezzo il viaggio si salva lo stesso', (
      tester,
    ) async {
      caricaCatalogoDelRepo();
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      expect(savedTrip().transports, isEmpty);
    });

    testWidgets('modificare il viaggio conserva i mezzi', (tester) async {
      caricaCatalogoDelRepo();
      final trip = TripModel(
        id: 'trip-1',
        name: 'Toscana',
        departureDateTime: DateTime(2026, 9, 12),
        returnDateTime: DateTime(2026, 9, 20),
        destinationLocation: LocationSuggestionModel(
          placeId: 'p',
          displayName: 'Siena, Italia',
          city: 'Siena',
        ),
        transports: const ['car'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
      when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});

      await pumpScreen(tester, open: '/trips/trip-1/edit-info');
      // Auto è già scelto; si aggiunge il Treno e si salva.
      await tester.ensureVisible(find.text('Treno'));
      await tester.tap(find.text('Treno'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit_trip_save')));
      await tester.pumpAndSettle();

      final updated =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(updated.transports, ['car', 'train']);
    });

    testWidgets(
      'una meta dalla ricerca dei luoghi si salva con le coordinate',
      (tester) async {
        await pumpScreen(tester);
        await tester.tap(_placeField);
        await tester.pump();
        await tester.enterText(_placeField, 'Mar');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('location_result_0')));
        await tester.pumpAndSettle();
        await _pickDates(tester);

        await tester.tap(find.byKey(const Key('new_trip_choose_items')));
        await tester.pumpAndSettle();

        final trip = savedTrip();
        expect(trip.destinationHouseId, isNull);
        expect(trip.destinationLocation?.displayName, 'Marsiglia, Francia');
        expect(trip.name, 'Marsiglia');
      },
    );

    testWidgets('con una meta scelta, Indietro chiede conferma', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Lasciare il nuovo viaggio?'), findsOneWidget);
      expect(find.text('Nuovo viaggio'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.text('Lasciare il nuovo viaggio?'), findsNothing);
      expect(find.text('Nuovo viaggio'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();

      expect(find.text('trips-tab'), findsOneWidget);
      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('senza niente, Indietro esce subito', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Lasciare il nuovo viaggio?'), findsNothing);
      expect(find.text('trips-tab'), findsOneWidget);
    });
  });

  group('NewTripScreen — nome del viaggio', () {
    testWidgets('segue la meta finché non lo modifichi', (tester) async {
      await pumpScreen(tester);

      await _pickHouse(tester, 'h1');
      expect(_nameText(tester), 'Casa Milano');

      // Via la meta e scegline un'altra: il nome proposto cambia.
      await tester.tap(find.byKey(const Key('new_trip_clear_destination')));
      await tester.pumpAndSettle();
      await _pickHouse(tester, 'h2');
      expect(_nameText(tester), 'Casa al mare');

      // Scritto a mano, il nome non segue più la meta.
      await tester.enterText(_nameField, 'Weekend');
      await tester.pump();
      await tester.tap(find.byKey(const Key('new_trip_clear_destination')));
      await tester.pumpAndSettle();
      await _pickHouse(tester, 'h1');
      expect(_nameText(tester), 'Weekend');
    });
  });

  group('NewTripScreen — tappe', () {
    testWidgets('Aggiungi tappa mette la riga in coda all\'itinerario', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await _addStop(tester, houseId: 'h2', endDay: 14);

      expect(find.text('Casa al mare'), findsOneWidget);
      expect(find.text('trips.new.stops_tip'), findsNothing);
    });

    testWidgets('tocco su una tappa apre la sua modifica', (tester) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      await _addStop(tester, houseId: 'h2', endDay: 14);

      await tester.tap(find.text('Casa al mare'));
      await tester.pumpAndSettle();

      expect(find.text('Modifica tappa'), findsOneWidget);
      expect(
        tester.widget<TextField>(_stopPlaceField).controller!.text,
        'Casa al mare',
      );
    });

    testWidgets('modificare la tappa dalla riga cambia il posto', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      await _addStop(tester, houseId: 'h2', endDay: 14);

      await tester.tap(find.text('Casa al mare'));
      await tester.pumpAndSettle();
      await tester.tap(_stopPlaceField);
      await tester.pump();
      await tester.enterText(_stopPlaceField, 'Casa in');
      await tester.pump();
      await tester.tap(find.byKey(const Key('place_search_house_h3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop_sheet_save')));
      await tester.pumpAndSettle();

      expect(find.text('Casa in montagna'), findsOneWidget);
      expect(find.text('Casa al mare'), findsNothing);
    });

    testWidgets(
      'con le date fuori ordine la riga toccata è la tappa giusta e la elimina',
      (tester) async {
        await pumpScreen(tester);
        await _pickHouse(tester, 'h1');
        await _pickDates(tester);
        await _addStop(tester, houseId: 'h2', endDay: 14);
        await _addStop(tester, houseId: 'h3', endDay: 16);

        // La meta finisce il 15: la tappa B ("Casa al mare") finisce il 14,
        // prima di iniziare. Per data C verrebbe prima di B, ma le righe
        // restano nell'ordine della catena: A, B, C.
        await _moveDestinationEnd(tester, _day(15));
        final mare = tester.getTopLeft(find.text('Casa al mare')).dy;
        final montagna = tester.getTopLeft(find.text('Casa in montagna')).dy;
        expect(mare, lessThan(montagna));

        await tester.tap(find.text('Casa in montagna'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_stopPlaceField).controller!.text,
          'Casa in montagna',
        );

        await tester.tap(find.byKey(const Key('stop_sheet_remove')));
        await tester.pumpAndSettle();

        expect(find.text('Casa in montagna'), findsNothing);
        expect(find.text('Casa al mare'), findsOneWidget);
      },
    );

    testWidgets('una tappa a zero notti blocca "Scegli tu cosa portare"', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      await _addStop(tester, houseId: 'h2', endDay: 14);

      // La meta finisce il 14, come la tappa che parte da lì: zero notti.
      await _moveDestinationEnd(tester, _day(14));

      expect(
        find.text('Casa al mare finisce prima di iniziare: controlla le date.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('new_trip_choose_items')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('un salvataggio che fallisce riabilita il bottone', (
      tester,
    ) async {
      when(() => tripRepo.addTrip(any())).thenThrow(Exception('offline'));
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      // Durante il salvataggio il bottone gira: niente pumpAndSettle finché
      // il dialogo d'errore non chiude, altrimenti lo spinner non si ferma mai.
      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Errore di salvataggio'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.text('Nuovo viaggio'), findsOneWidget);
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('new_trip_choose_items')))
            .isLoading,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => tripRepo.addTrip(any())).called(2);
    });

    testWidgets('durante il salvataggio il back non esce né chiede conferma', (
      tester,
    ) async {
      final saving = Completer<void>();
      when(() => tripRepo.addTrip(any())).thenAnswer((_) => saving.future);
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(find.text('Lasciare il nuovo viaggio?'), findsNothing);
      expect(find.text('Nuovo viaggio'), findsOneWidget);

      saving.complete();
      await tester.pumpAndSettle();
      final trip = savedTrip();
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
    });
  });
}
