import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
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
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockSpaceRepository extends Mock implements SpaceRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

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
}) => _viaggio(
  items: items ?? _suitcaseItems,
  aiResult: AiPackingResult(
    generatedAt: DateTime(2026, 10, 24),
    houseId: 'h1',
    proposal: _suitcaseProposal,
    warnings: warnings,
    reasons: reasons,
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

  /// Risultato che la pagina finta del pack-trip restituisce ("Risultato").
  late AiPackingResult? aiOutcome;

  /// Lavori passati alla pagina finta del pack-trip.
  late List<PackTripJob> jobs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_viaggio());
    registerFallbackValue(_maglietta);
  });

  setUp(() {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    luggageRepo = MockLuggageRepository();
    spaceRepo = MockSpaceRepository();
    lifecycle = MockTripLifecycleService();
    analytics = MockCoreAnalyticsService();
    sync = MockSyncOrchestrator();
    aiOutcome = null;
    jobs = [];

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
  Future<void> pumpPack(WidgetTester tester, {bool direct = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PackSuitcaseScreen packPage(GoRouterState state) => PackSuitcaseScreen(
      tripId: state.pathParameters['id']!,
      startAi: state.uri.queryParameters['ai'] == '1',
    );

    final router = GoRouter(
      initialLocation: direct ? '/trips/trip-1/edit-items?ai=1' : '/trips',
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
          syncOrchestratorProvider.overrideWithValue(sync),
          tripWeatherNotifierProvider('trip-1').overrideWith(_Weather.new),
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
    if (!direct) {
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
          of: find.byType(AlertDialog),
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
        await tapInSheet(tester, 'Prepara la valigia');
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
      'la riga degli avvisi apre il foglio; "Ok, capito" toglie l avviso e "Fatto" lo salva',
      (tester) async {
        arrange(
          trip: _viaggioAi(warnings: [_avvisoBoxer]),
          items: _houseItems,
        );
        await pumpPack(tester);

        await tapKey(tester, const Key('pack_row_missing'));
        expect(find.byType(DsFormSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.text(_avvisoBoxer.title),
          ),
          findsOneWidget,
        );
        expect(find.text('Importante'), findsOneWidget);

        await tapKey(tester, const Key('ai_warning_dismiss_w1'));
        expect(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.text(_avvisoBoxer.title),
          ),
          findsNothing,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Non manca niente'), findsOneWidget);

        await tapText(tester, 'Fatto · 4 oggetti');

        final saved = savedTrip().aiResult!;
        expect(saved.dismissedWarnings, ['w1']);
        expect(saved.openWarnings, isEmpty);
      },
    );

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

    testWidgets('"Importante" è in ambra, "Utile" in grigio', (tester) async {
      arrange(
        trip: _viaggioAi(warnings: [_avvisoBoxer, _avvisoSenzaCerca]),
        items: _houseItems,
      );
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_row_missing'));

      final context = tester.element(find.text('Utile'));
      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(colorOf('Importante'), context.appColors.warning);
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

    testWidgets('senza avvisi la riga dice "Non manca niente"', (tester) async {
      arrange(trip: _viaggioAi(), items: _houseItems);
      await pumpPack(tester);

      expect(find.text('Non manca niente'), findsOneWidget);
      expect(find.text('Perché queste scelte'), findsOneWidget);
    });
  });

  /// Apre il foglio dal tocco sull'icona, lo chiude con "Prepara la valigia" e
  /// torna dalla pagina finta con [aiOutcome].
  Future<void> generate(WidgetTester tester) async {
    await tapKey(tester, const Key('pack_ai_suitcase'));
    await tapInSheet(tester, 'Prepara la valigia');
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
        await tapInSheet(tester, 'Prepara la valigia');

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
            'Non sono riuscito a leggere gli oggetti della casa: la proposta è salva, ma la valigia non è cambiata.',
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
        await tapInSheet(tester, 'Prepara la valigia');

        // Gli oggetti si leggono, ma la scrittura della valigia fallisce.
        when(() => tripRepo.updateTrip(any())).thenThrow(Exception('offline'));
        await tapText(tester, 'Risultato');
        // La finestra d'errore del salvataggio: si annulla.
        await tapText(tester, 'Annulla');

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            'Non sono riuscito a leggere gli oggetti della casa: la proposta è salva, ma la valigia non è cambiata.',
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
}
