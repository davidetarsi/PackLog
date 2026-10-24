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
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/pack_suitcase_screen.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_parts.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/quantity_stepper.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockSpaceRepository extends Mock implements SpaceRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

final _milano = HouseModel(
  id: 'h1',
  name: 'Casa Milano',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _mare = HouseModel(
  id: 'h2',
  name: 'Casa al mare',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ItemModel _item(
  String id,
  String name,
  ItemCategory category, {
  int? quantity,
  String houseId = 'h1',
}) => ItemModel(
  id: id,
  houseId: houseId,
  name: name,
  category: category,
  quantity: quantity,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// La casa del test: quattro capi (uno è in valigia da 4 pezzi), due capi
/// fuori dalla valigia e tre oggetti non da vestiti.
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
final _caricatore = _item(
  'i-caricatore',
  'Caricatore',
  ItemCategory.elettronica,
);
final _pila = _item('i-pila', 'Pila', ItemCategory.varie);

final _houseItems = [
  _maglietta,
  _boxer,
  _calzino,
  _scarponi,
  _felpa,
  _spazzolino,
  _caricatore,
  _pila,
];

const _note =
    "Ho scelto i vestiti e l'essenziale per l'igiene. Il resto lo scegli tu: lo trovi in fondo alla valigia.";

const _reasonEveryday = AiReason(
  code: 'tutti_i_giorni',
  label: 'Tutti i giorni',
  sentence: 'Da usare tutti i giorni',
);

AiPackedItem _packed(
  String itemId, {
  int quantity = 1,
  bool inDeparture = false,
  AiReason reason = _reasonEveryday,
}) => AiPackedItem(
  itemId: itemId,
  quantity: quantity,
  inDeparture: inDeparture,
  reason: reason,
);

TripItem _tripItem(ItemModel item, {int quantity = 1}) => TripItem(
  id: item.id,
  name: item.name,
  category: item.category,
  quantity: quantity,
  originHouseId: item.houseId,
);

/// La valigia della proposta: maglietta 1, boxer 4, calzino 1, scarponi 1
/// (da indossare in partenza).
List<TripItem> get _suitcaseItems => [
  _tripItem(_maglietta),
  _tripItem(_boxer, quantity: 4),
  _tripItem(_calzino),
  _tripItem(_scarponi),
];

List<AiPackedItem> get _suitcaseProposal => [
  _packed('i-maglietta'),
  _packed('i-boxer', quantity: 4),
  _packed('i-calzino'),
  _packed('i-scarponi', inDeparture: true),
];

TripModel _trip({List<TripItem> items = const [], AiPackingResult? aiResult}) =>
    TripModel(
      id: 'trip-1',
      name: 'Islanda',
      items: items,
      aiResult: aiResult,
      departureDateTime: DateTime(2099, 10, 29),
      returnDateTime: DateTime(2099, 11, 3),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Viaggio con la valigia AI, casa h1.
TripModel _aiTrip({List<TripItem>? items, List<AiPackedItem>? proposal}) =>
    _trip(
      items: items ?? _suitcaseItems,
      aiResult: AiPackingResult(
        generatedAt: DateTime(2026, 10, 24),
        houseId: 'h1',
        proposal: proposal ?? _suitcaseProposal,
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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_trip());
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

    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});
    when(() => spaceRepo.getSpacesByHouseId(any())).thenAnswer((_) async => []);
  });

  /// Stub dei repository. Le case e gli oggetti sono quelli passati.
  void arrange({
    required TripModel trip,
    List<HouseModel>? houses,
    List<ItemModel> items = const [],
  }) {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    when(
      () => houseRepo.getAllHouses(),
    ).thenAnswer((_) async => houses ?? [_milano]);
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer(
      (invocation) async => items
          .where((i) => i.houseId == invocation.positionalArguments.first)
          .toList(),
    );
    when(() => itemRepo.addItem(any())).thenAnswer((_) async {});
    when(
      () => luggageRepo.getAllLuggages(),
    ).thenAnswer((_) async => <LuggageModel>[]);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => <LuggageModel>[]);
  }

  Future<void> pumpPack(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/trips',
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
          builder: (context, state) =>
              PackSuitcaseScreen(tripId: state.pathParameters['id']!),
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
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  /// La riga di un oggetto della valigia.
  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PackItemRow));

  Finder stepperOf(String name) =>
      find.descendant(of: rowOf(name), matching: find.byType(QuantityStepper));

  /// Il pulsante "+" o "-" della riga, con il suo stato.
  IconButton stepperButton(WidgetTester tester, String name, IconData icon) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.descendant(of: rowOf(name), matching: find.byIcon(icon)),
          matching: find.byType(IconButton),
        ),
      );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Il salvataggio: l'ultimo viaggio passato a `updateTrip`.
  TripModel savedTrip() =>
      verify(() => tripRepo.updateTrip(captureAny())).captured.single
          as TripModel;

  group('PackSuitcaseScreen — valigia generata', () {
    testWidgets('si vedono solo gli oggetti in valigia', (tester) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      expect(find.text('Maglietta'), findsOneWidget);
      expect(find.text('Boxer'), findsOneWidget);
      expect(find.text('Calzino'), findsOneWidget);
      expect(find.text('Scarponi'), findsOneWidget);
      // Fuori dalla valigia: né nella lista né nel gruppo chiuso.
      expect(find.text('Felpa'), findsNothing);
      expect(find.text('Spazzolino'), findsNothing);
      expect(find.text('Caricatore'), findsNothing);
      expect(find.text('Pila'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('niente caselle, e il selettore "Da" non c è', (tester) async {
      arrange(trip: _aiTrip(), houses: [_milano, _mare], items: _houseItems);
      await pumpPack(tester);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Da'), findsNothing);
      expect(find.widgetWithText(PackPill, 'Casa Milano'), findsNothing);
      expect(find.widgetWithText(PackPill, 'Casa al mare'), findsNothing);
    });

    testWidgets('la nota grigia dice cosa è stato scelto', (tester) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      expect(find.text(_note), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('il capo da indossare in partenza lo dice sotto il nome', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      expect(
        find.descendant(
          of: rowOf('Scarponi'),
          matching: find.text('Da indossare in partenza'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowOf('Maglietta'),
          matching: find.text('Da indossare in partenza'),
        ),
        findsNothing,
      );
    });

    testWidgets('boxer salvati 4 e in valigia 4: stepper con + spento', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      expect(stepperOf('Boxer'), findsOneWidget);
      expect(
        find.descendant(of: rowOf('Boxer'), matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        stepperButton(tester, 'Boxer', Icons.add_circle_outline).onPressed,
        isNull,
      );
      expect(
        stepperButton(tester, 'Boxer', Icons.remove_circle_outline).onPressed,
        isNotNull,
      );
    });

    testWidgets('calzino unico: niente stepper', (tester) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      expect(stepperOf('Calzino'), findsNothing);
      expect(stepperOf('Scarponi'), findsNothing);
    });

    testWidgets('il meno a 1 toglie l oggetto e lo dice con Annulla', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tester.ensureVisible(
        find.descendant(
          of: rowOf('Maglietta'),
          matching: find.byIcon(Icons.remove_circle_outline),
        ),
      );
      await tester.tap(
        find.descendant(
          of: rowOf('Maglietta'),
          matching: find.byIcon(Icons.remove_circle_outline),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tolto: Maglietta'), findsOneWidget);
      expect(find.text('Maglietta'), findsNothing);
    });

    testWidgets('× toglie, e Annulla rimette con la stessa quantità', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_remove_i-boxer'));
      expect(find.text('Boxer'), findsNothing);
      expect(find.text('Tolto: Boxer'), findsOneWidget);

      await tapText(tester, 'Annulla');
      expect(rowOf('Boxer'), findsOneWidget);
      expect(
        find.descendant(of: rowOf('Boxer'), matching: find.text('4')),
        findsOneWidget,
      );
    });

    testWidgets('togliere e annullare non cambia "Fatto" né salva modifiche', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tapKey(tester, const Key('pack_remove_i-boxer'));
      await tapText(tester, 'Annulla');
      await tapText(tester, 'Fatto · 4 oggetti');

      final saved = savedTrip();
      expect(saved.items.map((i) => i.id), containsAll(['i-boxer']));
      expect(saved.items.firstWhere((i) => i.id == 'i-boxer').quantity, 4);
    });

    testWidgets('il salvataggio conserva la valigia AI del viaggio', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tapText(tester, 'Fatto · 4 oggetti');

      final saved = savedTrip();
      expect(saved.aiResult, isNotNull);
      expect(saved.aiResult!.houseId, 'h1');
      expect(saved.aiResult!.proposal, hasLength(4));
    });

    testWidgets(
      '"Dalla casa" è chiuso e conta gli oggetti non vestiti fuori dalla valigia',
      (tester) async {
        arrange(trip: _aiTrip(), items: _houseItems);
        await pumpPack(tester);

        expect(find.text('Dalla casa · 3 oggetti'), findsOneWidget);
        expect(
          find.text('Toiletries, elettronica e varie: li scegli tu'),
          findsOneWidget,
        );
        expect(find.text('Spazzolino'), findsNothing);
      },
    );

    testWidgets(
      '"Dalla casa" aperto mostra solo i non vestiti e "+ Aggiungi" sposta l oggetto nella lista',
      (tester) async {
        arrange(trip: _aiTrip(), items: _houseItems);
        await pumpPack(tester);

        await tapText(tester, 'Dalla casa · 3 oggetti');
        expect(find.text('Spazzolino'), findsOneWidget);
        expect(find.text('Caricatore'), findsOneWidget);
        expect(find.text('Pila'), findsOneWidget);
        expect(find.text('Felpa'), findsNothing);

        await tapKey(tester, const Key('ai_home_add_i-spazzolino'));

        expect(rowOf('Spazzolino'), findsOneWidget);
        expect(find.text('Dalla casa · 2 oggetti'), findsOneWidget);
        expect(find.text('Aggiunto: Spazzolino'), findsOneWidget);
      },
    );

    testWidgets('"Dalla casa" vuoto non si disegna', (tester) async {
      arrange(
        trip: _aiTrip(
          items: [
            ..._suitcaseItems,
            _tripItem(_spazzolino),
            _tripItem(_caricatore),
            _tripItem(_pila),
          ],
          proposal: [
            ..._suitcaseProposal,
            _packed('i-spazzolino'),
            _packed('i-caricatore'),
            _packed('i-pila'),
          ],
        ),
        items: _houseItems,
      );
      await pumpPack(tester);

      expect(find.textContaining('Dalla casa'), findsNothing);
    });

    testWidgets(
      'un oggetto in valigia cancellato dalla casa si vede, senza stepper e senza eccezioni',
      (tester) async {
        final ghost = TripItem(
          id: 'i-ghost',
          name: 'Ciabatte',
          category: ItemCategory.toiletries,
          quantity: 2,
          originHouseId: 'h1',
        );
        arrange(
          trip: _aiTrip(
            items: [ghost],
            proposal: [_packed('i-ghost', quantity: 2)],
          ),
          items: _houseItems,
        );
        await pumpPack(tester);

        expect(find.text('Ciabatte'), findsOneWidget);
        expect(stepperOf('Ciabatte'), findsNothing);

        await tapText(tester, 'Ciabatte');
        expect(tester.takeException(), isNull);
        expect(find.byType(DsFormSheet), findsNothing);

        await tapKey(tester, const Key('pack_remove_i-ghost'));
        expect(find.text('Ciabatte'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'un viaggio senza valigia AI mostra ancora caselle e selettore',
      (tester) async {
        arrange(
          trip: _trip(items: [_tripItem(_maglietta)]),
          houses: [_milano, _mare],
          items: _houseItems,
        );
        await pumpPack(tester);

        expect(find.byType(Checkbox), findsWidgets);
        expect(find.text('Da'), findsOneWidget);
        expect(find.text(_note), findsNothing);
        expect(find.text('Dalla casa · 3 oggetti'), findsNothing);
      },
    );
  });

  group('PackSuitcaseScreen — aggiungere dal tuo armadio', () {
    testWidgets('la ricerca cerca fra gli oggetti della casa non in valigia', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      expect(find.text('Aggiungi dal tuo armadio'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'felp');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pack_ai_result_i-felpa')), findsOneWidget);
      // Le cose già in valigia non tornano tra i risultati.
      await tester.enterText(find.byType(TextField), 'magl');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pack_ai_result_i-maglietta')), findsNothing);
    });

    testWidgets(
      'il tocco su un risultato aggiunge con quantità 1 e Annulla lo toglie',
      (tester) async {
        arrange(trip: _aiTrip(), items: _houseItems);
        await pumpPack(tester);

        await tester.enterText(find.byType(TextField), 'felp');
        await tester.pumpAndSettle();
        await tapKey(tester, const Key('pack_ai_result_i-felpa'));

        expect(find.text('Aggiunto: Felpa'), findsOneWidget);
        expect(rowOf('Felpa'), findsOneWidget);
        expect(stepperOf('Felpa'), findsNothing);

        await tapText(tester, 'Annulla');
        // La ricerca è ancora "felp": Felpa torna tra i risultati, non in lista.
        expect(rowOf('Felpa'), findsNothing);
        expect(find.byKey(const Key('pack_ai_result_i-felpa')), findsOneWidget);
      },
    );

    testWidgets('aggiunto dalla ricerca, "Fatto" lo salva con quantità 1', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tester.enterText(find.byType(TextField), 'felp');
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('pack_ai_result_i-felpa'));
      await tapText(tester, 'Fatto · 5 oggetti');

      final felpa = savedTrip().items.firstWhere((i) => i.id == 'i-felpa');
      expect(felpa.quantity, 1);
    });

    testWidgets('con una ricerca senza risultati compare la riga "Aggiungi"', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tester.enterText(find.byType(TextField), 'ombrello');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pack_add_row')), findsOneWidget);
    });
  });

  group('PackSuitcaseScreen — scheda dell oggetto', () {
    testWidgets(
      'il tocco sul nome apre la scheda con il perché e la quantità',
      (tester) async {
        arrange(trip: _aiTrip(), items: _houseItems);
        await pumpPack(tester);

        await tapText(tester, 'Maglietta');

        expect(find.byType(DsFormSheet), findsOneWidget);
        expect(find.text('Perché è in valigia'), findsOneWidget);
        expect(find.text('Tutti i giorni'), findsOneWidget);
        expect(find.text('Da usare tutti i giorni'), findsOneWidget);
        expect(find.text("Ne hai 3 nell'armadio"), findsOneWidget);
        expect(find.text('Togli dalla valigia'), findsOneWidget);
      },
    );

    testWidgets(
      'nella scheda lo stepper cambia la quantità e "Fatto" la salva',
      (tester) async {
        arrange(trip: _aiTrip(), items: _houseItems);
        await pumpPack(tester);

        await tapText(tester, 'Maglietta');
        await tester.tap(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.byIcon(Icons.add_circle_outline),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: rowOf('Maglietta'), matching: find.text('2')),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(DsFormSheet),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
        await tapText(tester, 'Fatto · 4 oggetti');
        final maglietta = savedTrip().items.firstWhere(
          (i) => i.id == 'i-maglietta',
        );
        expect(maglietta.quantity, 2);
      },
    );

    testWidgets('la scheda di un capo in quantità singola non ha lo stepper', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tapText(tester, 'Calzino');

      expect(find.text("Ne hai 1 nell'armadio"), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.byType(QuantityStepper),
        ),
        findsNothing,
      );
    });

    testWidgets('la scheda di un capo da indossare in partenza lo dice', (
      tester,
    ) async {
      arrange(trip: _aiTrip(), items: _houseItems);
      await pumpPack(tester);

      await tapText(tester, 'Scarponi');

      expect(
        find.text(
          'Da indossare in partenza: è ingombrante e così non occupa spazio in valigia.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '"Togli dalla valigia" chiude la scheda e lo dice con Annulla',
      (tester) async {
        arrange(trip: _aiTrip(), items: _houseItems);
        await pumpPack(tester);

        await tapText(tester, 'Maglietta');
        await tapText(tester, 'Togli dalla valigia');

        expect(find.byType(DsFormSheet), findsNothing);
        expect(rowOf('Maglietta'), findsNothing);
        expect(find.text('Tolto: Maglietta'), findsOneWidget);
      },
    );
  });
}
