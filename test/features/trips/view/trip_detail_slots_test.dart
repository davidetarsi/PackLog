import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../helpers/mock_suitcase_edits.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_pack_reassurance.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/features/trips/view/widgets/slots/trip_items_card.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_checkbox.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';
import 'package:pack_log/shared/widgets/quantity_stepper.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

final _casa = HouseModel(
  id: 'h1',
  name: 'Casa',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripItem _item(
  String id,
  String name,
  ItemCategory category, {
  bool checked = false,
}) => TripItem(
  id: id,
  name: name,
  category: category,
  quantity: 1,
  isChecked: checked,
);

ItemModel _inventoryItem(String id, String name, {int? quantity}) => ItemModel(
  id: id,
  houseId: 'h1',
  name: name,
  category: ItemCategory.varie,
  quantity: quantity,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AiSlot _slot(
  String id,
  String name, {
  ItemCategory category = ItemCategory.vestiti,
  AiSlotLevel level = AiSlotLevel.useful,
  int copies = 1,
  int? remaining,
  String? reason,
  bool toBuy = false,
  bool checked = false,
}) => AiSlot(
  id: id,
  type: id,
  category: category,
  level: level,
  name: name,
  copies: copies,
  remaining: remaining ?? copies,
  reason: reason,
  addLabel: 'Aggiungi la tua',
  toBuy: toBuy,
  checked: checked,
);

/// Gli oggetti dell'utente: due in elettronica, due in varie.
List<TripItem> _items({int checked = 0}) => [
  _item('i-aux', 'Aux bt', ItemCategory.elettronica, checked: checked > 0),
  _item(
    'i-power',
    'Power bank',
    ItemCategory.elettronica,
    checked: checked > 1,
  ),
  _item('i-cuscino', 'Cuscino aereo', ItemCategory.varie),
  _item('i-coperta', 'Coperta di seta', ItemCategory.varie),
];

/// I nove utili, tutti nei vestiti: una sola card dei proposti.
List<AiSlot> get _useful => [
  _slot('u-maglioni', 'Maglioni caldi', copies: 3),
  _slot('u-termico', 'Strato termico', copies: 2),
  _slot('u-magliette', 'Magliette', copies: 5),
  _slot('u-pantaloni', 'Pantaloni', copies: 3),
  _slot('u-calzini', 'Calzini pesanti', copies: 7),
  _slot('u-mutande', 'Mutande', copies: 7),
  _slot('u-pigiama', 'Pigiama'),
  _slot('u-felpa', 'Felpa'),
  _slot('u-ciabatte', 'Ciabatte'),
];

/// Quattro importanti aperti e uno da comprare, come nel mockup.
List<AiSlot> _important({bool open = true}) => [
  _slot(
    'imp-giacca',
    'Giacca invernale',
    level: AiSlotLevel.important,
    remaining: open ? 1 : 0,
    reason: 'Fino a -7°: nell’armadio non c’è una giacca adatta.',
  ),
  _slot(
    'imp-scarpe',
    'Scarpe invernali',
    level: AiSlotLevel.important,
    remaining: open ? 1 : 0,
    reason: 'Non tengono freddo e neve.',
  ),
  _slot(
    'imp-cappello',
    'Cappello caldo',
    level: AiSlotLevel.important,
    remaining: open ? 1 : 0,
    reason: 'La testa scoperta si sente.',
  ),
  _slot(
    'imp-guanti',
    'Guanti',
    level: AiSlotLevel.important,
    remaining: open ? 1 : 0,
    reason: 'Sotto zero quasi ogni mattina.',
  ),
  _slot(
    'imp-sciarpa',
    'Sciarpa',
    level: AiSlotLevel.important,
    remaining: open ? 1 : 0,
    toBuy: true,
  ),
];

TripModel _trip({
  List<TripItem>? items,
  AiPackingResult? aiResult,
  bool withResult = true,
  DateTime? departureDateTime,
}) => TripModel(
  id: 'trip-1',
  name: 'Seul',
  departureDateTime: departureDateTime,
  items: items ?? _items(),
  aiResult: withResult
      ? aiResult ??
            AiPackingResult(
              generatedAt: DateTime(2026, 11),
              houseId: 'h1',
              slots: [..._important(), ..._useful],
              reasons: const [
                AiReasonPoint(
                  code: 'why',
                  title: 'Una scelta utile',
                  sentences: ['Motivo del viaggio'],
                ),
              ],
            )
      : null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;
  late MockLuggageRepository luggageRepo;
  late MockTripLifecycleService lifecycle;
  late MockCoreAnalyticsService analytics;
  late MockSyncOrchestrator sync;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_trip());
  });

  setUp(() {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    luggageRepo = MockLuggageRepository();
    lifecycle = MockTripLifecycleService();
    analytics = MockCoreAnalyticsService();
    sync = MockSyncOrchestrator();

    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});
    when(
      () => tripRepo.setTripItemChecked(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [_casa]);
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer((_) async => []);
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => []);
  });

  /// Con [fromHome] il dettaglio sta sopra una pagina di partenza: si può
  /// lasciarlo con `pop`. Torna il router.
  Future<GoRouter> pumpDetail(
    WidgetTester tester,
    TripModel trip, {
    bool fromHome = false,
    bool showNeeds = true,
    bool firstReview = false,
    Size size = const Size(390, 4000),
    double textScale = 1,
  }) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    // Alta abbastanza da costruire tutta la lista.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: fromHome ? '/home' : '/trips/trip-1',
      routes: [
        if (fromHome)
          GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/trips', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/trips/:id/needs',
          builder: (context, state) => TripDetailScreen(
            tripId: state.pathParameters['id']!,
            showNeeds: true,
            initialSlotId: state.uri.queryParameters['slot'],
          ),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) => TripDetailScreen(
            tripId: state.pathParameters['id']!,
            showNeeds: showNeeds,
            firstReview: firstReview,
            initialSlotId: state.uri.queryParameters['slot'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          ...noopSuitcaseEditsOverrides(),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          luggageRepositoryProvider.overrideWithValue(luggageRepo),
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
              theme: AppTheme.dark,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (fromHome) {
      unawaited(router.push('/trips/trip-1'));
      await tester.pumpAndSettle();
    }
    return router;
  }

  Finder inProposed(Finder finder) =>
      find.descendant(of: find.byType(ProposedSlotsCard), matching: finder);

  group('valigia fatta di posti', () {
    testWidgets('prima revisione nasconde le checkbox degli oggetti propri', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), showNeeds: false, firstReview: true);

      expect(find.byType(DsCheckbox), findsNothing);
      expect(find.byKey(const Key('trip_item_remove_i-aux')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('trip_item_remove_i-aux'))).dx,
        lessThan(tester.getTopLeft(find.text('Aux bt')).dx),
      );
    });

    testWidgets('vista necessità mostra i posti senza righe proprie', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), showNeeds: true);

      expect(find.byKey(const Key('slot_card_imp-giacca')), findsOneWidget);
      expect(find.byKey(const Key('trip_item_i-aux')), findsNothing);
      expect(find.byType(DsCheckbox), findsNothing);
    });

    testWidgets('prima della partenza c è la frase rassicurante', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), showNeeds: false);
      expect(find.byType(AiPackReassurance), findsOneWidget);

      await pumpDetail(tester, _trip(), showNeeds: false, firstReview: true);
      expect(find.byType(AiPackReassurance), findsOneWidget);
    });

    testWidgets('a viaggio partito la frase rassicurante non c è', (
      tester,
    ) async {
      final partito = _trip(departureDateTime: DateTime(2020, 1, 1));
      await pumpDetail(tester, partito, showNeeds: false);
      expect(find.byType(AiPackReassurance), findsNothing);

      await pumpDetail(tester, partito, showNeeds: false, firstReview: true);
      expect(find.byType(AiPackReassurance), findsNothing);
    });

    testWidgets('nella pagina necessità la frase non c è', (tester) async {
      await pumpDetail(tester, _trip(), showNeeds: true);
      expect(find.byType(AiPackReassurance), findsNothing);
    });

    testWidgets('Fatto chiude la prima revisione e torna ai Viaggi', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), showNeeds: false, firstReview: true);

      expect(find.text('Fatto'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip_detail_cta')));
      await tester.pumpAndSettle();

      expect(find.byType(TripDetailScreen), findsNothing);
    });

    testWidgets(
      'solo acquisti utili restano visibili senza propri o importanti',
      (tester) async {
        await pumpDetail(
          tester,
          _trip(
            items: const [],
            aiResult: AiPackingResult(
              generatedAt: DateTime(2026, 11),
              houseId: 'h1',
              slots: [
                _slot(
                  'u-buy',
                  'Cavo USB',
                  level: AiSlotLevel.useful,
                  toBuy: true,
                ),
              ],
            ),
          ),
          showNeeds: true,
        );

        expect(find.byKey(const Key('slot_to_buy_row_u-buy')), findsOneWidget);
        expect(find.byType(EmptySuitcase), findsNothing);
        expect(find.byType(ImportantSlotCard), findsNothing);
        expect(find.byType(DsCheckbox), findsNothing);
        expect(find.text('Vestiti · 1'), findsOneWidget);
      },
    );

    testWidgets('apertura normale conserva le spunte sugli oggetti propri', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(items: _items(checked: 1)),
        showNeeds: false,
      );

      expect(find.byKey(const Key('trip_item_i-aux')), findsOneWidget);
      expect(find.byKey(const Key('trip_item_remove_i-aux')), findsNothing);
      expect(find.byType(DsCheckbox), findsNWidgets(4));
      expect(find.byKey(const Key('trip_detail_cta')), findsNothing);
    });

    testWidgets(
      'errore aggiunta inventario resta gestito e non aggiunge righe',
      (tester) async {
        final inventoryItem = _inventoryItem('i-new', 'Custodia');
        when(
          () => itemRepo.getItemsByHouseId('h1'),
        ).thenAnswer((_) async => [inventoryItem]);
        when(
          () => tripRepo.updateTrip(any()),
        ).thenThrow(StateError('save failed'));
        final trip = _trip();
        await pumpDetail(tester, trip, showNeeds: false);

        await tester.enterText(find.byType(TextField).first, 'Custodia');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pack_inventory_result_i-new')));
        await tester.pumpAndSettle();

        expect(trip.items.any((item) => item.id == 'i-new'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('errore quantità è mostrato senza future non gestite', (
      tester,
    ) async {
      when(() => itemRepo.getItemsByHouseId('h1')).thenAnswer(
        (_) async => [_inventoryItem('i-aux', 'Aux bt', quantity: 3)],
      );
      var attempts = 0;
      when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {
        if (attempts++ == 0) throw StateError('save failed');
      });
      await pumpDetail(
        tester,
        _trip(items: _items(checked: 1)),
        showNeeds: false,
      );

      await tester.tap(find.byKey(const Key('trip_item_i-aux')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(find.byType(QuantityStepper), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuantityStepper),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(QuantityStepper),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      final saved =
          verify(() => tripRepo.updateTrip(captureAny())).captured.last
              as TripModel;
      expect(
        saved.items.firstWhere((entry) => entry.id == 'i-aux').isChecked,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('diminuire copie conserva la spunta', (tester) async {
      when(() => itemRepo.getItemsByHouseId('h1')).thenAnswer(
        (_) async => [_inventoryItem('i-aux', 'Aux bt', quantity: 3)],
      );
      final items = [
        _items(checked: 1).first.copyWith(quantity: 3),
        ..._items(checked: 1).skip(1),
      ];
      await pumpDetail(tester, _trip(items: items), showNeeds: false);

      await tester.tap(find.byKey(const Key('trip_item_i-aux')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      final saved =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(
        saved.items.firstWhere((entry) => entry.id == 'i-aux').isChecked,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('errore salvataggio bagaglio è gestito', (tester) async {
      when(() => luggageRepo.getAllLuggages()).thenAnswer(
        (_) async => [
          LuggageModel(
            id: 'l1',
            name: 'Trolley',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );
      when(
        () => tripRepo.updateTrip(any()),
      ).thenThrow(StateError('save failed'));
      await pumpDetail(tester, _trip(), showNeeds: false);

      await tester.tap(find.text('Trolley'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'la X toglie solo dal viaggio e Annulla ripristina ordine e spunta',
      (tester) async {
        var stored = _trip(items: _items(checked: 1));
        final beforeRemoval = stored.updatedAt;
        when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [stored]);
        when(() => tripRepo.updateTrip(any())).thenAnswer((call) async {
          stored = call.positionalArguments.first as TripModel;
        });
        await pumpDetail(tester, stored, showNeeds: false, firstReview: true);
        when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [stored]);
        await tester.tap(find.byKey(const Key('trip_item_remove_i-aux')));
        await tester.pumpAndSettle();
        expect(stored.items.map((i) => i.id), [
          'i-power',
          'i-cuscino',
          'i-coperta',
        ]);
        expect(find.byKey(const Key('trip_item_i-aux')), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(stored.updatedAt.isAfter(beforeRemoval), isTrue);
        final beforeUndo = stored.updatedAt;
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(stored.items.map((i) => i.id), [
          'i-aux',
          'i-power',
          'i-cuscino',
          'i-coperta',
        ]);
        expect(stored.items.first.isChecked, isTrue);
        expect(stored.updatedAt.isAfter(beforeUndo), isTrue);
        expect(find.byKey(const Key('trip_item_i-aux')), findsOneWidget);
      },
    );

    testWidgets(
      'Annulla e una nuova X si salvano in ordine senza perdere il ripristino',
      (tester) async {
        var stored = _trip(items: _items(checked: 1));
        final undoGate = Completer<void>();
        addTearDown(() {
          if (!undoGate.isCompleted) undoGate.complete();
        });
        var writes = 0;
        when(() => tripRepo.updateTrip(any())).thenAnswer((call) async {
          final next = call.positionalArguments.first as TripModel;
          writes++;
          if (writes == 2) await undoGate.future;
          stored = next;
        });
        await pumpDetail(tester, stored, showNeeds: false, firstReview: true);
        when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [stored]);
        await tester.tap(find.byKey(const Key('trip_item_remove_i-aux')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annulla'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('trip_item_remove_i-power')));
        await tester.pump();
        expect(writes, 2, reason: 'La seconda X deve attendere il ripristino');
        undoGate.complete();
        await tester.pumpAndSettle();
        expect(stored.items.map((i) => i.id), [
          'i-aux',
          'i-cuscino',
          'i-coperta',
        ]);
        expect(stored.items.first.isChecked, isTrue);
      },
    );

    testWidgets('card → necessità → ritorno mantiene l aggiornamento salvato', (
      tester,
    ) async {
      var stored = _trip();
      when(() => tripRepo.updateTrip(any())).thenAnswer((call) async {
        stored = call.positionalArguments.first as TripModel;
      });
      final router = await pumpDetail(tester, stored, showNeeds: false);

      expect(find.byKey(const Key('slot_card_imp-giacca')), findsNothing);
      await tester.tap(find.byKey(const Key('pack_row_missing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slot_card_imp-giacca')), findsOneWidget);
      await tester.tap(find.byKey(const Key('slot_to_buy_imp-giacca')));
      await tester.pumpAndSettle();
      expect(
        stored.aiResult!.slots!.firstWhere((s) => s.id == 'imp-giacca').toBuy,
        isTrue,
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slot_card_imp-giacca')), findsNothing);
      expect(find.byKey(const Key('pack_row_missing')), findsOneWidget);
      expect(
        stored.items.map((item) => item.id),
        _items().map((item) => item.id),
      );
    });

    for (final (size, scale) in [
      (const Size(320, 640), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(320, 640), 1.6),
    ]) {
      testWidgets('ultima riga raggiungibile a $size testo $scale', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          _trip(
            items: [
              ..._items(),
              _item('ultimo', 'Ultimo oggetto', ItemCategory.varie),
            ],
          ),
          size: size,
          textScale: scale,
          showNeeds: false,
          firstReview: true,
        );
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();

        final ultima = find.byKey(const Key('trip_item_ultimo'));
        expect(ultima, findsOneWidget);
        final ultimaRect = tester.getRect(ultima);
        final ctaRect = tester.getRect(
          find.byKey(const Key('trip_detail_cta')),
        );
        expect(
          ultimaRect.bottom,
          lessThanOrEqualTo(ctaRect.top),
          reason:
              'ultima=$ultimaRect, CTA=$ctaRect, '
              'max=${scroll.position.maxScrollExtent}, '
              'offset=${scroll.position.pixels}',
        );
        expect(ultima.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('necessità: ultima riga non vestiti raggiungibile', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          items: const [],
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [
              ..._important(),
              ..._useful,
              _slot(
                'imp-borraccia',
                'Borraccia',
                category: ItemCategory.varie,
                level: AiSlotLevel.important,
              ),
            ],
          ),
        ),
        size: const Size(320, 640),
        showNeeds: true,
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final ultima = find.byKey(const Key('slot_card_imp-borraccia'));
      expect(ultima, findsOneWidget);
      expect(ultima.hitTestable(), findsOneWidget);
      final rowRect = tester.getRect(ultima);
      final viewportRect = tester.getRect(find.byType(ListView));
      expect(rowRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
    });

    testWidgets('pagina principale separa necessità e motivi dagli oggetti', (
      tester,
    ) async {
      final trip = _trip();
      await pumpDetail(
        tester,
        trip.copyWith(
          aiResult: trip.aiResult!.copyWith(
            reasons: const [
              AiReasonPoint(
                code: 'why',
                title: 'Una scelta utile',
                sentences: ['Motivo del viaggio'],
              ),
            ],
          ),
        ),
        showNeeds: false,
      );

      expect(find.byKey(const Key('pack_row_missing')), findsOneWidget);
      expect(find.byKey(const Key('pack_row_reasons')), findsOneWidget);
      expect(find.textContaining('4 importanti'), findsOneWidget);
      expect(find.textContaining('9 suggerimenti'), findsOneWidget);
      expect(find.textContaining('comprare'), findsOneWidget);
      expect(find.byType(ImportantSlotCard), findsNothing);
      expect(find.byType(ProposedSlotsCard), findsNothing);
      expect(find.byType(ToBuySlotRow), findsNothing);
      expect(find.byKey(const Key('trip_item_i-aux')), findsOneWidget);
      expect(find.byType(DsCheckbox), findsNWidgets(4));
    });

    testWidgets('"Da comprare" sposta la card fra le righe da comprare, '
        'Annulla la riporta', (tester) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_to_buy_imp-giacca')));
      await tester.pumpAndSettle();

      expect(find.byType(ImportantSlotCard), findsNWidgets(3));
      expect(find.byType(ToBuySlotRow), findsNWidgets(2));
      expect(find.text('Ho comprato'), findsNWidgets(2));
      expect(find.text('Segnato da comprare'), findsOneWidget);

      final saved =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(
        saved.aiResult!.slots!.firstWhere((s) => s.id == 'imp-giacca').toBuy,
        isTrue,
      );

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportantSlotCard), findsNWidgets(4));
      expect(find.byType(ToBuySlotRow), findsOneWidget);
      final undone =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(
        undone.aiResult!.slots!.firstWhere((s) => s.id == 'imp-giacca').toBuy,
        isFalse,
      );
    });

    testWidgets('importanti chiusi: nessuna checkbox sui proposti', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          items: _items(checked: 1),
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [..._important(open: false), ..._useful],
          ),
        ),
      );

      expect(find.byType(ImportantSlotCard), findsNothing);
      expect(find.byType(ToBuySlotRow), findsNothing);
      expect(inProposed(find.byType(DsCheckbox)), findsNothing);
      expect(find.byKey(const Key('slot_row_u-maglioni')), findsOneWidget);
    });

    testWidgets('le informazioni del viaggio sotto la testata', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: _useful,
            notes: const [
              AiTripNote(
                code: 'lavanderia',
                title: 'Prevedi una lavanderia',
                why: 'Per 31 notti i vestiti non bastano.',
              ),
            ],
          ),
        ),
      );

      expect(find.byType(TripNoteRow), findsOneWidget);
      expect(find.text('Prevedi una lavanderia'), findsOneWidget);
      expect(find.text('Per 31 notti i vestiti non bastano.'), findsOneWidget);
    });

    testWidgets('senza oggetti né posti: lo stato vuoto di oggi', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          items: const [],
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: const [],
          ),
        ),
      );

      expect(find.byType(DsEmptyState), findsOneWidget);
      expect(find.byType(SuitcaseProgressHeader), findsNothing);
      expect(find.textContaining('pronti'), findsNothing);
    });
  });

  group('togliere un posto', () {
    AiSlot savedSlot(WidgetTester tester, String id) =>
        verify(() => tripRepo.updateTrip(captureAny())).captured
            .cast<TripModel>()
            .last
            .aiResult!
            .slots!
            .firstWhere((s) => s.id == id);

    testWidgets('X su un importante: dialog, "Togli", la card sparisce', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_remove_imp-giacca')));
      await tester.pumpAndSettle();
      expect(find.text('Togli Giacca invernale?'), findsOneWidget);
      expect(
        find.textContaining(
          'PackLog la considera importante per questo viaggio.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('nell’armadio non c’è'), findsNWidgets(2));

      await tester.tap(find.text('Togli'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot_card_imp-giacca')), findsNothing);
      expect(find.byType(ImportantSlotCard), findsNWidgets(3));
      expect(savedSlot(tester, 'imp-giacca').removed, isTrue);
    });

    testWidgets('X su un importante da comprare lo rimuove con Annulla', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_not_useful_imp-sciarpa')));
      await tester.pumpAndSettle();
      expect(find.text('Togli Sciarpa?'), findsNothing);
      expect(
        find.byKey(const Key('slot_to_buy_row_imp-sciarpa')),
        findsNothing,
      );
      expect(savedSlot(tester, 'imp-sciarpa').removed, isTrue);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('slot_to_buy_row_imp-sciarpa')),
        findsOneWidget,
      );
      expect(savedSlot(tester, 'imp-sciarpa').removed, isFalse);
    });

    testWidgets('X poi "Annulla": la card resta', (tester) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_remove_imp-giacca')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot_card_imp-giacca')), findsOneWidget);
      verifyNever(() => tripRepo.updateTrip(any()));
    });

    testWidgets(
      'Non utile scarta la proposta senza foglio e Annulla la ripristina',
      (tester) async {
        await pumpDetail(tester, _trip());

        await tester.tap(find.byKey(const Key('slot_not_useful_u-magliette')));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byKey(const Key('slot_row_u-magliette')), findsNothing);
        expect(savedSlot(tester, 'u-magliette').removed, isTrue);
        expect(find.byKey(const Key('trip_item_i-aux')), findsNothing);

        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('slot_row_u-magliette')), findsOneWidget);
        expect(savedSlot(tester, 'u-magliette').removed, isFalse);
        expect(find.byType(BottomSheet), findsNothing);
      },
    );

    testWidgets('scorrere una proposta: riga sparita, snack e Annulla', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());

      await tester.drag(
        find.byKey(const Key('slot_dismiss_u-magliette')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot_row_u-magliette')), findsNothing);
      expect(find.text('Tolta Magliette'), findsOneWidget);
      expect(find.text('Vestiti · 13'), findsOneWidget);
      expect(savedSlot(tester, 'u-magliette').removed, isTrue);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot_row_u-magliette')), findsOneWidget);
      expect(savedSlot(tester, 'u-magliette').removed, isFalse);
    });

    testWidgets('"Annulla" dopo aver lasciato la pagina ripristina il posto', (
      tester,
    ) async {
      final router = await pumpDetail(tester, _trip(), fromHome: true);

      await tester.drag(
        find.byKey(const Key('slot_dismiss_u-magliette')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsNothing);
      clearInteractions(tripRepo);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(savedSlot(tester, 'u-magliette').removed, isFalse);
    });

    testWidgets('una proposta da comprare non è nel dettaglio', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [
              ..._important(),
              ..._useful,
              _slot('u-sciarpa', 'Sciarpa leggera', toBuy: true),
            ],
          ),
        ),
        showNeeds: false,
      );

      expect(find.text('Sciarpa leggera'), findsNothing);
      expect(find.byKey(const Key('slot_row_u-sciarpa')), findsNothing);
      expect(find.textContaining('comprare'), findsOneWidget);
    });
  });

  group('risultato senza posti: la schermata di oggi', () {
    testWidgets('slots null: barra delle spunte, nessun posto', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
          ),
        ),
      );

      expect(find.text('0 di 4 in valigia'), findsOneWidget);
      expect(find.byKey(const Key('trip_detail_progress')), findsOneWidget);
      expect(find.byType(SuitcaseProgressHeader), findsNothing);
      expect(find.byType(ImportantSlotCard), findsNothing);
      expect(find.byType(ProposedSlotsCard), findsNothing);
      expect(find.text('Elettronica · 2'), findsOneWidget);
    });

    testWidgets('viaggio senza risultato: invariato', (tester) async {
      await pumpDetail(tester, _trip(withResult: false));

      expect(find.text('0 di 4 in valigia'), findsOneWidget);
      expect(find.byType(SuitcaseProgressHeader), findsNothing);

      await tester.tap(find.byKey(const Key('trip_item_i-aux')));
      await tester.pumpAndSettle();
      expect(find.text('1 di 4 in valigia'), findsOneWidget);
    });
  });
}
