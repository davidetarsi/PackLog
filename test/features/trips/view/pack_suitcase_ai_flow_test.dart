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
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
import 'package:pack_log/shared/widgets/ds_dialog.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/ai_packing_wait_screen.dart';
import 'package:pack_log/features/trips/view/pack_suitcase_screen.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/theme/theme.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockSpaceRepository extends Mock implements SpaceRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockAppAnalytics extends Mock implements AppAnalyticsService {}

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

/// I kit della casa h1, senza database.
class _Kits extends KitNotifier {
  _Kits(this.kits);

  final List<KitModel> kits;

  @override
  Future<List<KitModel>> build(String houseId) async => kits;
}

class _Weather extends TripWeatherNotifier {
  @override
  Future<TripWeatherState> build(String tripId) async =>
      const TripWeatherNotAvailable(WeatherUnavailable.past);
}

final _milano = HouseModel(
  id: 'h1',
  name: 'Casa Milano',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _zaino = LuggageModel(
  id: 'l1',
  name: 'Zaino blu',
  sizeType: LuggageSize.smallBackpack,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ItemModel _item(
  String id,
  String name,
  ItemCategory category, {
  int? quantity,
}) => ItemModel(
  id: id,
  houseId: 'h1',
  name: name,
  category: category,
  quantity: quantity,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _maglietta = _item(
  'i-maglietta',
  'Maglietta',
  ItemCategory.vestiti,
  quantity: 3,
);
final _boxer = _item('i-boxer', 'Boxer', ItemCategory.vestiti, quantity: 4);
final _calzino = _item('i-calzino', 'Calzino', ItemCategory.vestiti);
final _scarponi = _item('i-scarponi', 'Scarponi', ItemCategory.vestiti);
final _felpa = _item('i-felpa', 'Felpa', ItemCategory.vestiti);
final _spazzolino = _item(
  'i-spazzolino',
  'Spazzolino',
  ItemCategory.toiletries,
);

final _houseItems = [
  _maglietta,
  _boxer,
  _calzino,
  _scarponi,
  _felpa,
  _spazzolino,
];

TripItem _tripItem(ItemModel item, {int quantity = 1}) => TripItem(
  id: item.id,
  name: item.name,
  category: item.category,
  quantity: quantity,
  originHouseId: 'h1',
);

final _suitcaseItems = [
  _tripItem(_maglietta),
  _tripItem(_boxer, quantity: 4),
  _tripItem(_calzino),
  _tripItem(_scarponi),
];

const _reasonEveryday = AiReason(
  code: 'tutti_i_giorni',
  label: 'Tutti i giorni',
  sentence: 'Da usare tutti i giorni',
);

AiPackedItem _packed(String itemId, {int quantity = 1}) =>
    AiPackedItem(itemId: itemId, quantity: quantity, reason: _reasonEveryday);

final _suitcaseProposal = [
  _packed('i-maglietta'),
  _packed('i-boxer', quantity: 4),
  _packed('i-calzino'),
  _packed('i-scarponi'),
];

final _avvisoBoxer = AiWarning(
  id: 'w1',
  code: 'boxer',
  level: AiWarningLevel.important,
  title: 'Ti servono più pezzi di boxer',
  why: 'Fino alla lavatrice ne servirebbero 6.',
  search: 'felp',
);

final _avvisoSenzaCerca = AiWarning(
  id: 'w2',
  code: 'pantaloni',
  level: AiWarningLevel.useful,
  title: 'Mancano dei pantaloni impermeabili',
  why: 'Pioggia quasi ogni giorno.',
);

/// Un viaggio fra dieci giorni, con coordinate: la valigia AI è disponibile.
final _partenza = DateTime.now().add(const Duration(days: 10));

TripModel _viaggio({
  List<TripItem> items = const [],
  AiPackingResult? aiResult,
  LocationSuggestionModel? destination,
}) => TripModel(
  id: 'trip-1',
  name: 'Islanda',
  items: items,
  aiResult: aiResult,
  destinationLocation:
      destination ??
      LocationSuggestionModel(
        placeId: 'p-rey',
        displayName: 'Reykjavik, Islanda',
        city: 'Reykjavik',
        country: 'Islanda',
        lat: 64.1,
        lon: -21.9,
      ),
  departureDateTime: _partenza,
  returnDateTime: _partenza.add(const Duration(days: 5)),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Viaggio con una valigia AI già fatta, casa h1.
TripModel _viaggioAi({
  List<TripItem>? items,
  List<AiWarning> warnings = const [],
  List<AiReasonPoint> reasons = const [],
  List<String> dismissed = const [],
}) => _viaggio(
  items: items ?? _suitcaseItems,
  aiResult: AiPackingResult(
    generatedAt: DateTime(2026, 10, 24),
    houseId: 'h1',
    proposal: _suitcaseProposal,
    warnings: warnings,
    reasons: reasons,
    dismissedWarnings: dismissed,
  ),
);

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;
  late MockLuggageRepository luggageRepo;
  late MockSpaceRepository spaceRepo;
  late MockTripLifecycleService lifecycle;
  late MockCoreAnalyticsService analytics;
  late MockSyncOrchestrator sync;
  late MockAppAnalytics appAnalytics;
  late _MemoryOnboardingRepository onboardingRepo;

  /// Risultato che la pagina finta del pack-trip restituisce ("Risultato").
  late AiPackingResult? aiOutcome;

  /// Lavori passati alla pagina finta del pack-trip.
  late List<PackTripJob> jobs;

  /// I kit della casa h1 che il foglio legge prima di chiamare la funzione.
  late List<KitModel> houseKits;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_viaggio());
    registerFallbackValue(_maglietta);
  });

  setUp(() {
    // Attività e alloggi del foglio vengono dal catalogo.
    caricaCatalogoDelRepo();
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    luggageRepo = MockLuggageRepository();
    spaceRepo = MockSpaceRepository();
    lifecycle = MockTripLifecycleService();
    analytics = MockCoreAnalyticsService();
    sync = MockSyncOrchestrator();
    appAnalytics = MockAppAnalytics();
    onboardingRepo = _MemoryOnboardingRepository();
    SharedPreferences.setMockInitialValues({});
    when(
      () => appAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    aiOutcome = null;
    jobs = [];
    houseKits = [];

    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});
    when(() => spaceRepo.getSpacesByHouseId(any())).thenAnswer((_) async => []);
  });

  /// Stub dei repository: il viaggio, le case, gli oggetti e i bagagli.
  void arrange({
    required TripModel trip,
    List<ItemModel> items = const [],
    List<LuggageModel> luggages = const [],
  }) {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [_milano]);
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer(
      (invocation) async => items
          .where((i) => i.houseId == invocation.positionalArguments.first)
          .toList(),
    );
    when(() => itemRepo.addItem(any())).thenAnswer((_) async {});
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => luggages);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => luggages);
  }

  /// Apre la pagina valigia: dalla pagina "trips" (tocco su "apri"), oppure
  /// direttamente con `?ai=1` se [direct].
  ///
  /// Con [fromNew] la pagina è il passo 2 di "Nuovo viaggio"; con [fromDetail]
  /// si parte dal dettaglio del viaggio, che apre la pagina con "apri". Il
  /// dettaglio finto mostra "Dettaglio viaggio".
  Future<void> pumpPack(
    WidgetTester tester, {
    bool direct = false,
    bool fromNew = false,
    bool fromDetail = false,
    bool firstRun = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PackSuitcaseScreen packPage(GoRouterState state) => PackSuitcaseScreen(
      tripId: state.pathParameters['id']!,
      startAi: state.uri.queryParameters['ai'] == '1',
      fromNewTrip: state.uri.queryParameters['from'] == 'new',
      firstRun: state.uri.queryParameters['first'] == '1',
    );

    final router = GoRouter(
      initialLocation: fromNew
          ? '/trips/trip-1/edit-items?from=new&ai=1${firstRun ? '&first=1' : ''}'
          : fromDetail
          ? '/trips/trip-1'
          : direct
          ? '/trips/trip-1/edit-items?ai=1'
          : '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/trips/trip-1/edit-items'),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Dettaglio viaggio'),
                ElevatedButton(
                  onPressed: () => context.push('/trips/trip-1/edit-items'),
                  child: const Text('apri'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (context, state) => packPage(state),
        ),
        // Pagina d'attesa finta: registra il lavoro e torna con [aiOutcome].
        GoRoute(
          path: '/trips/:id/ai-packing',
          builder: (context, state) {
            jobs.add(state.extra! as PackTripJob);
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pop<AiPackingResult>(aiOutcome),
                  child: const Text('Risultato'),
                ),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          luggageRepositoryProvider.overrideWithValue(luggageRepo),
          spaceRepositoryProvider.overrideWithValue(spaceRepo),
          categoryInferServiceProvider.overrideWith(
            (ref) => Completer<CategoryInferService>().future,
          ),
          tripLifecycleServiceProvider.overrideWithValue(lifecycle),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
          analyticsServiceProvider.overrideWithValue(appAnalytics),
          onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          syncOrchestratorProvider.overrideWithValue(sync),
          tripWeatherNotifierProvider('trip-1').overrideWith(_Weather.new),
          kitNotifierProvider('h1').overrideWith(() => _Kits(houseKits)),
        ],
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!direct && !fromNew) {
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Il tocco su un testo dentro il foglio aperto.
  Future<void> tapInSheet(WidgetTester tester, String text) async {
    final finder = find.descendant(
      of: find.byType(DsFormSheet),
      matching: find.text(text),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Chiude il foglio con "Prepara la valigia". Attività e alloggio sono
  /// obbligatori: se la tappa non li ha già, si sceglie Città e musei e Hotel.
  Future<void> prepareInSheet(WidgetTester tester) async {
    for (final label in ['Città e musei', 'Hotel']) {
      final pill = find.descendant(
        of: find.byType(DsFormSheet),
        matching: find.widgetWithText(DsChoicePill, label),
      );
      if (pill.evaluate().isNotEmpty &&
          !tester.widget<DsChoicePill>(pill).selected) {
        await tapInSheet(tester, label);
      }
    }
    await tapInSheet(tester, 'Prepara la valigia');
  }

  /// Tutti i salvataggi del viaggio, in ordine.
  List<TripModel> savedTrips() => verify(
    () => tripRepo.updateTrip(captureAny()),
  ).captured.cast<TripModel>();

  /// L'ultimo viaggio passato a `updateTrip`.
  TripModel savedTrip() => savedTrips().last;

  group('valigia AI: icona Prepara con AI / Rigenera', () {
    testWidgets('con la valigia piena chiede se sostituirla', (tester) async {
      arrange(trip: _viaggioAi(), items: _houseItems);
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_ai_suitcase'));

      expect(find.text('Vuoi sostituire la valigia?'), findsOneWidget);
      expect(jobs, isEmpty);
    });

    testWidgets('con "Annulla" la domanda chiude e il foglio non si apre', (
      tester,
    ) async {
      arrange(trip: _viaggioAi(), items: _houseItems);
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_ai_suitcase'));
      await tester.tap(
        find.descendant(
          of: find.byType(DsDialog),
          matching: find.text('Annulla'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vuoi sostituire la valigia?'), findsNothing);
      expect(find.text('Valigia con AI'), findsNothing);
      expect(jobs, isEmpty);
    });

    testWidgets(
      'risposta del foglio e risultato: la pagina mostra la proposta e salva aiSetup e aiResult',
      (tester) async {
        aiOutcome = AiPackingResult(
          generatedAt: DateTime(2026, 10, 24),
          houseId: 'h1',
          proposal: _suitcaseProposal,
        );
        arrange(trip: _viaggio(), items: _houseItems, luggages: [_zaino]);
        await pumpPack(tester);

        await tapKey(tester, const Key('pack_ai_suitcase'));
        await tapInSheet(tester, 'Zaino blu');
        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        expect(jobs, hasLength(1));
        expect(jobs.single.houseId, 'h1');
        expect(jobs.single.body['house_id'], 'h1');

        // Prima il salvataggio delle risposte, poi quello del risultato.
        final saves = savedTrips();
        expect(saves.first.aiSetup?.houseId, 'h1');
        expect(saves.last.aiSetup?.houseId, 'h1');
        expect(saves, hasLength(2));
        expect(saves.last.aiResult?.proposal, hasLength(4));
        expect(saves.last.luggages.map((l) => l.id), ['l1']);

        expect(find.text('Maglietta'), findsOneWidget);
        expect(find.text('Boxer'), findsOneWidget);
        expect(find.text('Felpa'), findsNothing);
        expect(find.text('Fatto · 4 oggetti'), findsOneWidget);
      },
    );

    testWidgets('con la valigia vuota il foglio si apre senza domanda', (
      tester,
    ) async {
      arrange(trip: _viaggio(), items: _houseItems);
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_ai_suitcase'));

      expect(find.text('Vuoi sostituire la valigia?'), findsNothing);
      expect(find.text('Valigia con AI'), findsOneWidget);
    });

    testWidgets('senza coordinate l icona lo dice con la snackbar e non genera', (
      tester,
    ) async {
      arrange(
        trip: _viaggio(
          destination: LocationSuggestionModel(
            placeId: 'p-x',
            displayName: 'Luogo senza mappa',
            city: 'Luogo senza mappa',
            country: 'Islanda',
          ),
        ),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_ai_suitcase'));

      expect(
        find.text(
          'Una tappa non ha ancora una posizione sulla mappa: impostala per preparare la valigia con AI.',
        ),
        findsOneWidget,
      );
      expect(find.text('Valigia con AI'), findsNothing);
      expect(jobs, isEmpty);
      verifyNever(() => tripRepo.updateTrip(any()));
    });

    testWidgets('startAi apre il foglio da solo, senza domanda', (
      tester,
    ) async {
      arrange(trip: _viaggio(), items: _houseItems);
      await pumpPack(tester, direct: true);

      expect(find.text('Valigia con AI'), findsOneWidget);
      expect(find.text('Vuoi sostituire la valigia?'), findsNothing);
    });
  });

  group('valigia AI: avvisi e motivi', () {
    testWidgets(
      '"Ok, capito" segna l avviso come letto: resta nel foglio e si salva subito',
      (tester) async {
        arrange(
          trip: _viaggioAi(warnings: [_avvisoBoxer]),
          items: _houseItems,
        );
        await pumpPack(tester);

        expect(find.text('Cosa manca a questo viaggio'), findsOneWidget);
        await tapKey(tester, const Key('pack_row_missing'));
        expect(find.byType(DsFormSheet), findsOneWidget);
        expect(find.text('Importante'), findsOneWidget);

        await tapKey(tester, const Key('ai_warning_dismiss_w1'));

        // L'avviso resta, segnato come letto e senza "Ok, capito".
        expect(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.text(_avvisoBoxer.title),
          ),
          findsOneWidget,
        );
        expect(find.text('Letto'), findsOneWidget);
        expect(find.text('Importante'), findsNothing);
        expect(find.byKey(const Key('ai_warning_dismiss_w1')), findsNothing);
        expect(find.byKey(const Key('ai_warning_search_w1')), findsOneWidget);

        // Salvato senza "Fatto".
        final saved = savedTrip().aiResult!;
        expect(saved.dismissedWarnings, ['w1']);

        await tester.tap(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();

        // La riga resta da riaprire, senza il numero dei non letti.
        expect(find.text('Cosa manca a questo viaggio'), findsOneWidget);
        expect(find.text('Non manca niente'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('pack_row_missing')),
            matching: find.text('1'),
          ),
          findsNothing,
        );

        await tapKey(tester, const Key('pack_row_missing'));
        expect(find.text('Letto'), findsOneWidget);
      },
    );

    testWidgets('gli avvisi letti vanno in fondo, dopo quelli da leggere', (
      tester,
    ) async {
      arrange(
        trip: _viaggioAi(
          warnings: [_avvisoBoxer, _avvisoSenzaCerca],
          dismissed: const ['w1'],
        ),
        items: _houseItems,
      );
      await pumpPack(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('pack_row_missing')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, const Key('pack_row_missing'));
      final unread = tester.getTopLeft(find.byKey(const Key('ai_warning_w2')));
      final read = tester.getTopLeft(find.byKey(const Key('ai_warning_w1')));
      expect(unread.dy, lessThan(read.dy));
    });

    testWidgets('segnare un avviso come letto non chiede conferma uscendo', (
      tester,
    ) async {
      arrange(
        trip: _viaggioAi(warnings: [_avvisoBoxer]),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_row_missing'));
      await tapKey(tester, const Key('ai_warning_dismiss_w1'));
      await tester.tap(
        find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Uscire senza salvare?'), findsNothing);
      expect(find.text('apri'), findsOneWidget);
    });

    testWidgets('uscendo con modifiche dice che la valigia AI resta salvata', (
      tester,
    ) async {
      arrange(trip: _viaggioAi(), items: _houseItems);
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_remove_i-calzino'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Uscire senza salvare?'), findsOneWidget);
      expect(
        find.text(
          "Le modifiche fatte dopo andranno perse. La valigia preparata "
          "dall'AI resta salvata.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Cerca nell armadio" chiude il foglio e scrive la ricerca', (
      tester,
    ) async {
      arrange(
        trip: _viaggioAi(warnings: [_avvisoBoxer]),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_row_missing'));
      await tapKey(tester, const Key('ai_warning_search_w1'));

      expect(find.byType(DsFormSheet), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'felp',
      );
      expect(find.byKey(const Key('pack_ai_result_i-felpa')), findsOneWidget);
    });

    testWidgets('senza ricerca il bottone "Cerca nell armadio" non c è', (
      tester,
    ) async {
      arrange(
        trip: _viaggioAi(warnings: [_avvisoSenzaCerca]),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_row_missing'));

      expect(find.byKey(const Key('ai_warning_search_w2')), findsNothing);
      expect(find.byKey(const Key('ai_warning_dismiss_w2')), findsOneWidget);
    });

    testWidgets('"Importante" è in arancio scuro, "Utile" in grigio', (
      tester,
    ) async {
      arrange(
        trip: _viaggioAi(warnings: [_avvisoBoxer, _avvisoSenzaCerca]),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_row_missing'));

      final context = tester.element(find.text('Utile'));
      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(
        colorOf('Importante'),
        Theme.of(context).colorScheme.onPrimaryContainer,
      );
      expect(colorOf('Utile'), Theme.of(context).colorScheme.onSurfaceVariant);
    });

    testWidgets('la riga dei motivi apre il foglio con un punto per motivo', (
      tester,
    ) async {
      arrange(
        trip: _viaggioAi(
          reasons: const [
            AiReasonPoint(
              code: 'tutti_i_giorni',
              title: 'Tutti i giorni',
              sentences: ['Da usare tutti i giorni'],
              items: ['Maglietta', 'Boxer'],
            ),
          ],
        ),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_row_reasons'));

      expect(find.byType(DsFormSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.text('Perché queste scelte'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.text('Da usare tutti i giorni'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('senza motivi la riga "Perché queste scelte" non c\'è', (
      tester,
    ) async {
      arrange(trip: _viaggioAi(), items: _houseItems);
      await pumpPack(tester);

      expect(find.byKey(const Key('pack_row_missing')), findsOneWidget);
      expect(find.byKey(const Key('pack_row_reasons')), findsNothing);
      expect(find.text('Perché queste scelte'), findsNothing);
    });

    testWidgets('senza avvisi la riga dice "Non manca niente"', (tester) async {
      arrange(trip: _viaggioAi(), items: _houseItems);
      await pumpPack(tester);

      expect(find.text('Non manca niente'), findsOneWidget);
    });
  });

  /// Apre il foglio dal tocco sull'icona, lo chiude con "Prepara la valigia" e
  /// torna dalla pagina finta con [aiOutcome].
  Future<void> generate(WidgetTester tester) async {
    await tapKey(tester, const Key('pack_ai_suitcase'));
    await prepareInSheet(tester);
    await tapText(tester, 'Risultato');
  }

  group('valigia AI: esito e casi del risultato', () {
    testWidgets(
      'se gli oggetti della casa non si leggono la proposta si salva lo stesso',
      (tester) async {
        aiOutcome = AiPackingResult(
          generatedAt: DateTime(2026, 10, 24),
          houseId: 'h1',
          proposal: _suitcaseProposal,
        );
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PackSuitcaseScreen)),
        );
        await tapKey(tester, const Key('pack_ai_suitcase'));
        await prepareInSheet(tester);

        // Da qui in poi leggere gli oggetti della casa fallisce.
        when(
          () => itemRepo.getItemsByHouseId(any()),
        ).thenThrow(Exception('offline'));
        container.invalidate(itemNotifierProvider('h1'));
        await tester.pump();
        await tapText(tester, 'Risultato');

        expect(tester.takeException(), isNull);
        expect(jobs, hasLength(1));
        final saves = savedTrips();
        expect(saves.last.aiResult?.proposal, hasLength(4));
        expect(saves.last.aiSetup?.houseId, 'h1');
        // Capi e bagagli com'erano: la valigia non è cambiata.
        expect(saves.last.items, isEmpty);
        expect(
          find.text(
            'Non è stato possibile leggere gli oggetti della casa: la proposta è salvata, ma la valigia non è cambiata.',
          ),
          findsOneWidget,
        );

        // "Fatto" resta utilizzabile e salva la valigia AI.
        await tapText(tester, 'Fatto');
        expect(savedTrip().aiResult, isNotNull);
      },
    );

    testWidgets(
      'se il salvataggio della proposta fallisce non dice che la proposta è salva',
      (tester) async {
        aiOutcome = AiPackingResult(
          generatedAt: DateTime(2026, 10, 24),
          houseId: 'h1',
          proposal: _suitcaseProposal,
        );
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester);
        await tapKey(tester, const Key('pack_ai_suitcase'));
        await prepareInSheet(tester);

        // Gli oggetti si leggono, ma la scrittura della valigia fallisce.
        when(() => tripRepo.updateTrip(any())).thenThrow(Exception('offline'));
        await tapText(tester, 'Risultato');
        // La finestra d'errore del salvataggio: si annulla.
        await tapText(tester, 'Annulla');

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            'Non è stato possibile leggere gli oggetti della casa: la proposta è salvata, ma la valigia non è cambiata.',
          ),
          findsNothing,
        );
        expect(find.text('Errore di salvataggio'), findsOneWidget);
      },
    );

    testWidgets(
      'un capo della proposta non più in casa viene saltato, il resto si salva',
      (tester) async {
        aiOutcome = AiPackingResult(
          generatedAt: DateTime(2026, 10, 24),
          houseId: 'h1',
          proposal: [..._suitcaseProposal, _packed('i-fantasma')],
        );
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester);
        await generate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Maglietta'), findsOneWidget);
        expect(find.text('Scarponi'), findsOneWidget);
        expect(find.byKey(const Key('pack_remove_i-fantasma')), findsNothing);
        expect(find.text('Fatto · 4 oggetti'), findsOneWidget);

        final saved = savedTrips().last;
        expect(
          saved.items.map((i) => i.id),
          unorderedEquals([
            'i-maglietta',
            'i-boxer',
            'i-calzino',
            'i-scarponi',
          ]),
        );
        // La proposta resta quella intera del generatore.
        expect(saved.aiResult!.proposal, hasLength(5));
      },
    );

    testWidgets(
      'la quantità proposta sale al massimo dei pezzi salvati; senza quantità è uno',
      (tester) async {
        aiOutcome = AiPackingResult(
          generatedAt: DateTime(2026, 10, 24),
          houseId: 'h1',
          proposal: [
            _packed('i-maglietta', quantity: 9), // ne ha 3 salvati
            _packed('i-boxer', quantity: 4), // ne ha 4: invariato
            _packed('i-calzino', quantity: 5), // quantità null = 1
          ],
        );
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester);
        await generate(tester);

        final saved = {
          for (final item in savedTrips().last.items) item.id: item.quantity,
        };
        expect(saved['i-maglietta'], 3);
        expect(saved['i-boxer'], 4);
        expect(saved['i-calzino'], 1);
      },
    );
  });

  group('valigia AI: dopo la generazione si arriva alla valigia', () {
    AiSlot slot(
      String id,
      String type, {
      bool toBuy = false,
      AiSlotLevel level = AiSlotLevel.important,
    }) => AiSlot(
      id: id,
      type: type,
      category: ItemCategory.vestiti,
      level: level,
      name: type,
      copies: 1,
      remaining: 1,
      addLabel: 'Aggiungi',
      toBuy: toBuy,
    );

    AiPackingResult withSlots(List<AiSlot> slots) => AiPackingResult(
      generatedAt: DateTime(2026, 10, 24),
      houseId: 'h1',
      proposal: _suitcaseProposal,
      slots: slots,
    );

    testWidgets(
      'dal nuovo viaggio, con i posti, si arriva al dettaglio e il viaggio ha i posti',
      (tester) async {
        aiOutcome = withSlots([slot('s1', 'giacca')]);
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester, fromNew: true);

        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        expect(find.text('Dettaglio viaggio'), findsOneWidget);
        expect(find.byType(PackSuitcaseScreen), findsNothing);
        expect(find.text('Uscire senza salvare?'), findsNothing);
        final slots = savedTrip().aiResult?.slots;
        expect(slots, hasLength(1));
        expect(slots?.single.type, 'giacca');
      },
    );

    testWidgets(
      'rigenerando da "Modifica valigia" si torna al dettaglio e il "da comprare" resta',
      (tester) async {
        aiOutcome = withSlots([slot('n1', 'giacca'), slot('n2', 'sciarpa')]);
        arrange(
          trip: _viaggio(
            items: _suitcaseItems,
            aiResult: withSlots([slot('s1', 'giacca', toBuy: true)]),
          ),
          items: _houseItems,
        );
        await pumpPack(tester, fromDetail: true);
        expect(find.text('Dettaglio viaggio'), findsNothing);

        await tapKey(tester, const Key('pack_ai_suitcase'));
        await tapText(tester, 'Sostituisci');
        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        expect(find.text('Dettaglio viaggio'), findsOneWidget);
        expect(find.byType(PackSuitcaseScreen), findsNothing);
        final slots = savedTrip().aiResult!.slots!;
        expect(slots.firstWhere((s) => s.type == 'giacca').toBuy, isTrue);
        expect(slots.firstWhere((s) => s.type == 'sciarpa').toBuy, isFalse);
      },
    );

    for (final step in [
      OnboardingStep.aiIntro,
      OnboardingStep.houseDetailTooltip,
      OnboardingStep.createTripTooltip,
      OnboardingStep.tripCreationTooltip,
    ]) {
      testWidgets('generare a metà del tour (${step.name}) non cambia il '
          'passo', (tester) async {
        onboardingRepo.step = step;
        aiOutcome = withSlots([slot('s1', 'giacca')]);
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester, fromNew: true);

        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        expect(find.text('Dettaglio viaggio'), findsOneWidget);
        expect(onboardingRepo.step, step);
      });
    }

    testWidgets('la prima valigia chiude il passo "Dove vai?" (done)', (
      tester,
    ) async {
      aiOutcome = withSlots([slot('s1', 'giacca')]);
      arrange(trip: _viaggio(), items: _houseItems);
      await pumpPack(tester, fromNew: true, firstRun: true);
      expect(onboardingRepo.step, OnboardingStep.firstTrip);

      await prepareInSheet(tester);
      await tapText(tester, 'Risultato');

      expect(find.text('Dettaglio viaggio'), findsOneWidget);
      expect(onboardingRepo.step, OnboardingStep.done);
    });

    group('first_suitcase_generated', () {
      void verifyFirstSuitcase(Map<String, Object?> properties, int times) {
        verify(
          () => appAnalytics.logEvent(
            'first_suitcase_generated',
            properties: properties,
          ),
        ).called(times);
      }

      testWidgets('alla prima valigia con i posti, con i conteggi giusti', (
        tester,
      ) async {
        aiOutcome = withSlots([
          slot('s1', 'giacca'),
          slot('s2', 'sciarpa', level: AiSlotLevel.important),
          slot('s3', 'magliette', level: AiSlotLevel.useful),
        ]);
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester, fromNew: true, firstRun: true);

        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        verifyFirstSuitcase({
          'slots_important': 2,
          'slots_proposed': 1,
          'slots_total': 3,
          'trip_items': savedTrip().items.length,
          'from_first_run': true,
        }, 1);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'first_suitcase_logged',
          ),
          isTrue,
        );
      });

      testWidgets('fuori dal primo avvio from_first_run è falso', (
        tester,
      ) async {
        aiOutcome = withSlots([slot('s1', 'giacca')]);
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester, fromNew: true);

        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        verify(
          () => appAnalytics.logEvent(
            'first_suitcase_generated',
            properties: any(
              named: 'properties',
              that: containsPair('from_first_run', false),
            ),
          ),
        ).called(1);
      });

      testWidgets('non riparte se la chiave dice che è già partito', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'first_suitcase_logged': true});
        aiOutcome = withSlots([slot('s1', 'giacca')]);
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester, fromNew: true, firstRun: true);

        await prepareInSheet(tester);
        await tapText(tester, 'Risultato');

        verifyNever(
          () => appAnalytics.logEvent(
            'first_suitcase_generated',
            properties: any(named: 'properties'),
          ),
        );
      });

      testWidgets('alla seconda generazione non riparte', (tester) async {
        aiOutcome = withSlots([slot('n1', 'giacca')]);
        arrange(
          trip: _viaggio(
            items: _suitcaseItems,
            aiResult: withSlots([slot('s1', 'giacca')]),
          ),
          items: _houseItems,
        );
        await pumpPack(tester, fromDetail: true);

        for (var i = 0; i < 2; i++) {
          await tapKey(tester, const Key('pack_ai_suitcase'));
          await tapText(tester, 'Sostituisci');
          await prepareInSheet(tester);
          await tapText(tester, 'Risultato');
          if (i == 0) {
            await tester.tap(find.text('apri'));
            await tester.pumpAndSettle();
          }
        }

        verify(
          () => appAnalytics.logEvent(
            'first_suitcase_generated',
            properties: any(named: 'properties'),
          ),
        ).called(1);
      });

      testWidgets('un salvataggio fallito non lo emette', (tester) async {
        aiOutcome = withSlots([slot('s1', 'giacca')]);
        arrange(trip: _viaggio(), items: _houseItems);
        await pumpPack(tester, fromNew: true, firstRun: true);
        await prepareInSheet(tester);

        when(() => tripRepo.updateTrip(any())).thenThrow(Exception('offline'));
        await tapText(tester, 'Risultato');
        await tapText(tester, 'Annulla');

        verifyNever(
          () => appAnalytics.logEvent(
            'first_suitcase_generated',
            properties: any(named: 'properties'),
          ),
        );
      });
    });

    testWidgets('se il salvataggio fallisce la pagina resta', (tester) async {
      aiOutcome = withSlots([slot('s1', 'giacca')]);
      arrange(trip: _viaggio(), items: _houseItems);
      await pumpPack(tester, fromNew: true);
      await prepareInSheet(tester);

      when(() => tripRepo.updateTrip(any())).thenThrow(Exception('offline'));
      await tapText(tester, 'Risultato');
      await tapText(tester, 'Annulla');

      expect(find.text('Dettaglio viaggio'), findsNothing);
      expect(find.byType(PackSuitcaseScreen), findsOneWidget);
    });

    testWidgets('senza posti la pagina resta, come prima', (tester) async {
      aiOutcome = AiPackingResult(
        generatedAt: DateTime(2026, 10, 24),
        houseId: 'h1',
        proposal: _suitcaseProposal,
      );
      arrange(trip: _viaggio(), items: _houseItems);
      await pumpPack(tester, fromNew: true);
      await prepareInSheet(tester);
      await tapText(tester, 'Risultato');

      expect(find.text('Dettaglio viaggio'), findsNothing);
      expect(find.byType(PackSuitcaseScreen), findsOneWidget);
      expect(find.text('Fatto · 4 oggetti'), findsOneWidget);
    });

    testWidgets(
      'con i posti "Modifica valigia" non mostra "Cosa manca a questo viaggio"',
      (tester) async {
        arrange(
          trip: _viaggio(
            items: _suitcaseItems,
            aiResult: withSlots([slot('s1', 'giacca')]).copyWith(
              warnings: [_avvisoBoxer],
              reasons: const [
                AiReasonPoint(code: 'freddo', title: 'Fa freddo'),
              ],
            ),
          ),
          items: _houseItems,
        );
        await pumpPack(tester);

        expect(find.text('Cosa manca a questo viaggio'), findsNothing);
        expect(find.text('Ti servono più pezzi di boxer'), findsNothing);
        expect(find.text('Perché queste scelte'), findsOneWidget);
      },
    );
  });

  group('valigia AI: kit', () {
    KitModel kit(String id, List<KitItem> items) => KitModel(
      id: id,
      houseId: 'h1',
      name: 'Kit $id',
      activities: const ['ski'],
      items: items,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    KitItem row(String kitId, String itemId, [int copies = 1]) => KitItem(
      id: '$kitId-$itemId',
      kitId: kitId,
      itemId: itemId,
      copies: copies,
    );

    AiPackingResult outcome({
      List<AiKitAdded> added = const [],
      List<AiKitSuggestion> suggestions = const [],
      List<AiPackedItem>? proposal,
    }) => AiPackingResult(
      generatedAt: DateTime(2026, 11, 2),
      houseId: 'h1',
      proposal: proposal ?? _suitcaseProposal,
      kitAdded: added,
      kitSuggestions: suggestions,
    );

    Future<void> generate(WidgetTester tester) async {
      await pumpPack(tester, direct: true);
      await prepareInSheet(tester);
      await tapText(tester, 'Risultato');
    }

    testWidgets('risposta senza kit: valigia identica', (tester) async {
      houseKits = [
        kit('k1', [row('k1', 'i-felpa')]),
      ];
      aiOutcome = outcome();
      arrange(trip: _viaggio(), items: _houseItems);

      await generate(tester);

      // La funzione non ha risposto con `kit` (build vecchia): niente cambia.
      final saved = savedTrip();
      expect(saved.items.map((i) => (i.id, i.quantity)).toSet(), {
        for (final p in _suitcaseProposal) (p.itemId, p.quantity),
      });
      expect(saved.aiResult?.kitSuggestions, isEmpty);
    });

    testWidgets('la richiesta porta i kit della casa; senza kit niente campo', (
      tester,
    ) async {
      houseKits = [
        kit('k1', [row('k1', 'i-felpa', 2)]),
      ];
      aiOutcome = outcome();
      arrange(trip: _viaggio(), items: _houseItems);
      await generate(tester);

      final sent = jobs.single.body['kit'] as List;
      expect(sent, hasLength(1));
      expect((sent.single as Map)['id'], 'k1');
      expect((sent.single as Map)['oggetti'], [
        {'item_id': 'i-felpa', 'copie': 2},
      ]);
    });

    testWidgets('casa senza kit: nessun campo kit nel corpo', (tester) async {
      aiOutcome = outcome();
      arrange(trip: _viaggio(), items: _houseItems);
      await generate(tester);

      expect(jobs.single.body.containsKey('kit'), isFalse);
    });

    testWidgets('aggiunti diventano oggetti del viaggio', (tester) async {
      houseKits = [
        kit('k1', [row('k1', 'i-felpa'), row('k1', 'i-spazzolino')]),
      ];
      aiOutcome = outcome(
        added: const [
          AiKitAdded(kitId: 'k1', itemId: 'i-felpa'),
          AiKitAdded(kitId: 'k1', itemId: 'i-spazzolino'),
        ],
      );
      arrange(trip: _viaggio(), items: _houseItems);

      await generate(tester);

      final items = {for (final i in savedTrip().items) i.id: i};
      expect(items['i-felpa']?.name, 'Felpa');
      expect(items['i-felpa']?.quantity, 1);
      expect(items['i-felpa']?.originHouseId, 'h1');
      expect(items['i-spazzolino']?.category, ItemCategory.toiletries);
      // Gli altri oggetti della proposta restano.
      expect(items.keys, containsAll(['i-maglietta', 'i-boxer']));
    });

    testWidgets('copie: massimo, mai somma', (tester) async {
      aiOutcome = outcome(
        added: const [
          // Già proposto con 4: il kit ne porta 2, restano 4.
          AiKitAdded(kitId: 'k1', itemId: 'i-boxer', copies: 2),
          // Proposto con 1: due kit ne portano 2 e 3, vale 3 (non 5, non 1).
          AiKitAdded(kitId: 'k1', itemId: 'i-maglietta', copies: 2),
          AiKitAdded(kitId: 'k2', itemId: 'i-maglietta', copies: 3),
        ],
      );
      arrange(trip: _viaggio(), items: _houseItems);

      await generate(tester);

      final items = {for (final i in savedTrip().items) i.id: i.quantity};
      expect(items['i-boxer'], 4);
      expect(items['i-maglietta'], 3);
    });

    testWidgets('le copie non superano i pezzi in casa', (tester) async {
      aiOutcome = outcome(
        added: const [AiKitAdded(kitId: 'k1', itemId: 'i-felpa', copies: 5)],
      );
      arrange(trip: _viaggio(), items: _houseItems);

      await generate(tester);

      // La felpa ha quantità non salvata: vale 1 pezzo.
      final items = {for (final i in savedTrip().items) i.id: i.quantity};
      expect(items['i-felpa'], 1);
    });

    testWidgets('un oggetto non più in casa si salta', (tester) async {
      aiOutcome = outcome(
        added: const [
          AiKitAdded(kitId: 'k1', itemId: 'i-sparito'),
          AiKitAdded(kitId: 'k1', itemId: 'i-felpa'),
        ],
      );
      arrange(trip: _viaggio(), items: _houseItems);

      await generate(tester);

      final ids = savedTrip().items.map((i) => i.id);
      expect(ids, contains('i-felpa'));
      expect(ids, isNot(contains('i-sparito')));
    });

    testWidgets('suggeriti letti nell ordine e salvati col viaggio', (
      tester,
    ) async {
      aiOutcome = outcome(
        suggestions: const [
          AiKitSuggestion(
            kitId: 'k-b',
            taken: 1,
            total: 3,
            missing: [KitItemRef(itemId: 'i-felpa', copies: 1)],
          ),
          AiKitSuggestion(kitId: 'k-a', taken: 0, total: 2),
        ],
      );
      arrange(trip: _viaggio(), items: _houseItems);

      await generate(tester);

      final saved = savedTrip().aiResult!;
      expect(saved.kitSuggestions.map((s) => s.kitId), ['k-b', 'k-a']);
      expect(saved.kitSuggestions.first.missing.single.itemId, 'i-felpa');
    });

    testWidgets('rigenerazione azzera kitAnswers ma non i kit contati', (
      tester,
    ) async {
      final previous = AiPackingResult(
        generatedAt: DateTime(2026, 11, 1),
        houseId: 'h1',
        kitSuggestions: const [
          AiKitSuggestion(kitId: 'k1', taken: 1, total: 2),
        ],
        kitAnswers: const {'k1': 'added'},
        kitLearnCounted: const ['k1'],
      );
      aiOutcome = outcome(
        suggestions: const [AiKitSuggestion(kitId: 'k1', taken: 0, total: 2)],
      );
      arrange(
        trip: _viaggio(aiResult: previous),
        items: _houseItems,
      );

      await generate(tester);

      final saved = savedTrip().aiResult!;
      expect(saved.kitAnswers, isEmpty);
      expect(saved.kitLearnCounted, ['k1']);
      expect(saved.kitSuggestions.single.taken, 0);
    });
  });
}
