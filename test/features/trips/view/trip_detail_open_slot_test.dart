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
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/to_buy_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_rapid_fire_bar.dart';
import 'package:pack_log/features/trips/view/widgets/slots/open_slot_body.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/features/trips/view/widgets/slots/trip_items_card.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_icon_button.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockRawAnalytics extends Mock implements AppAnalyticsService {}

/// Registra gli oggetti creati dal Rapid Fire, senza toccare il database.
class _RecordingItemNotifier extends ItemNotifier {
  final added = <ItemModel>[];

  @override
  Future<List<ItemModel>> build(String houseId) async => const [];

  @override
  Future<void> addItem(ItemModel model, {bool categoryChosen = false}) async {
    added.add(model);
  }
}

final _casa = HouseModel(
  id: 'h1',
  name: 'Casa',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AiSlot _slot(
  String id,
  String name, {
  ItemCategory category = ItemCategory.vestiti,
  AiSlotLevel level = AiSlotLevel.useful,
  int copies = 1,
  bool toBuy = false,
}) => AiSlot(
  id: id,
  type: id,
  category: category,
  level: level,
  name: name,
  copies: copies,
  remaining: copies,
  addLabel: 'Aggiungi la tua',
  toBuy: toBuy,
);

/// Un viaggio con un oggetto già in valigia, un importante e i proposti dei
/// vestiti, più un gruppo "Varie" in fondo alla pagina.
TripModel _trip({List<AiSlot> extra = const []}) => TripModel(
  id: 'trip-1',
  name: 'Seul',
  items: [
    TripItem(
      id: 'it-felpa',
      name: 'Felpa grigia',
      category: ItemCategory.vestiti,
      quantity: 1,
      originHouseId: 'h1',
    ),
  ],
  aiResult: AiPackingResult(
    generatedAt: DateTime(2026, 11),
    houseId: 'h1',
    slots: [
      _slot('imp-giacca', 'Giacca invernale', level: AiSlotLevel.important),
      _slot('u-maglioni', 'Maglioni caldi', copies: 3),
      _slot('u-magliette', 'Magliette', copies: 5),
      _slot('u-calzini', 'Calzini pesanti', copies: 7),
      _slot('t-spazzolino', 'Spazzolino', category: ItemCategory.toiletries),
      _slot('t-dentifricio', 'Dentifricio', category: ItemCategory.toiletries),
      _slot('e-caricatore', 'Caricatore', category: ItemCategory.elettronica),
      _slot('v-ombrello', 'Ombrello', category: ItemCategory.varie),
      ...extra,
    ],
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockTripLifecycleService lifecycle;
  late MockCoreAnalyticsService analytics;
  late MockRawAnalytics rawAnalytics;
  late MockSyncOrchestrator sync;
  late _RecordingItemNotifier itemNotifier;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_trip());
  });

  setUp(() {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    lifecycle = MockTripLifecycleService();
    analytics = MockCoreAnalyticsService();
    rawAnalytics = MockRawAnalytics();
    when(
      () => rawAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    sync = MockSyncOrchestrator();
    itemNotifier = _RecordingItemNotifier();

    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [_casa]);
  });

  /// Con [fromHome] la pagina di dettaglio sta sopra una pagina di partenza;
  /// [height] è l'altezza dello schermo; [noAnimations] spegne le
  /// animazioni di sistema.
  Future<void> pumpDetail(
    WidgetTester tester,
    TripModel trip, {
    String? slot,
    bool fromHome = false,
    double height = 4000,
    bool noAnimations = false,
  }) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = slot == null ? '/trips/trip-1' : '/trips/trip-1?slot=$slot';
    final router = GoRouter(
      initialLocation: fromHome ? '/' : detail,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) => TripDetailScreen(
            tripId: state.pathParameters['id']!,
            initialSlotId: state.uri.queryParameters['slot'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          tripLifecycleServiceProvider.overrideWithValue(lifecycle),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
          analyticsServiceProvider.overrideWithValue(rawAnalytics),
          syncOrchestratorProvider.overrideWithValue(sync),
          itemNotifierProvider('h1').overrideWith(() => itemNotifier),
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
                ).copyWith(disableAnimations: noAnimations),
                child: child!,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (fromHome) {
      unawaited(router.push(detail));
      await tester.pumpAndSettle();
    }
  }

  final bar = find.byType(SlotRapidFireBar);
  final openBody = find.byType(OpenSlotBody);

  Finder inOpen(Finder finder) =>
      find.descendant(of: openBody, matching: finder);
  Finder inUserItems(Finder finder) =>
      find.descendant(of: find.byType(ItemsCard), matching: finder);
  Finder inRow(String slotId, Finder finder) => find.descendant(
    of: find.byKey(Key('slot_row_$slotId')),
    matching: finder,
  );

  Future<void> openMagliette(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('slot_row_u-magliette')));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
  }

  TripModel lastSaved() =>
      verify(() => tripRepo.updateTrip(captureAny())).captured.last
          as TripModel;

  /// Tocca la riga spenta di un oggetto dell'utente: fuori dal riquadro.
  Future<void> tapOutside(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const Key('trip_item_it-felpa')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"Magliette ×5" si apre come prima riga dei proposti, con la '
      'frase e il 5', (tester) async {
    await pumpDetail(tester, _trip());

    await openMagliette(tester);

    final card = find.ancestor(
      of: openBody,
      matching: find.byType(ProposedSlotsCard),
    );
    expect(card, findsOneWidget);
    expect(inOpen(find.text('Magliette')), findsOneWidget);
    expect(inOpen(find.text('×5')), findsOneWidget);
    expect(
      inOpen(
        find.text(
          'PackLog ne propone 5. Scrivi qui sotto quelle che hai davvero, '
          'anche più di una insieme («2 t-shirt nere»): prendono il loro '
          'posto.',
        ),
      ),
      findsOneWidget,
    );
    // Prima delle altre proposte, che prima stavano sopra.
    expect(find.byKey(const Key('slot_row_u-magliette')), findsNothing);
    expect(
      tester.getTopLeft(openBody).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('slot_row_u-maglioni'))).dy,
      ),
    );
    // Il resto è spento.
    expect(
      find.ancestor(
        of: find.byKey(const Key('slot_row_u-maglioni')),
        matching: find.byType(AbsorbPointer),
      ),
      findsWidgets,
    );
    expect(bar, findsOneWidget);
  });

  testWidgets('"2 t-shirt nere": ×3 e la riga nel riquadro, non fra gli '
      'oggetti dell\'utente', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);

    await send(tester, '2 t-shirt nere');

    expect(inOpen(find.text('×3')), findsOneWidget);
    expect(inOpen(find.text('T-shirt nere')), findsOneWidget);
    expect(inUserItems(find.text('T-shirt nere')), findsNothing);
    expect(inUserItems(find.text('Felpa grigia')), findsOneWidget);
  });

  testWidgets('un tocco fuori chiude: l\'oggetto va fra quelli dell\'utente '
      'e "Magliette ×3" torna fra le proposte', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);
    await send(tester, '2 t-shirt nere');

    await tapOutside(tester);

    expect(openBody, findsNothing);
    expect(bar, findsNothing);
    expect(inUserItems(find.text('T-shirt nere')), findsOneWidget);
    expect(inRow('u-magliette', find.text('Magliette')), findsOneWidget);
    expect(inRow('u-magliette', find.text('×3')), findsOneWidget);
  });

  testWidgets('un tocco su una proposta spenta chiude soltanto', (
    tester,
  ) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);

    await tester.tap(
      find.byKey(const Key('slot_row_u-maglioni')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(openBody, findsNothing);
    expect(bar, findsNothing);
  });

  testWidgets('il tasto indietro chiude come il tocco fuori e la pagina '
      'resta', (tester) async {
    await pumpDetail(tester, _trip(), fromHome: true);
    await openMagliette(tester);
    await send(tester, '2 t-shirt nere');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(openBody, findsNothing);
    expect(bar, findsNothing);
    expect(inUserItems(find.text('T-shirt nere')), findsOneWidget);
    expect(inRow('u-magliette', find.text('×3')), findsOneWidget);
  });

  testWidgets('l\'ultimo gruppo della pagina si apre in cima alla vista', (
    tester,
  ) async {
    await pumpDetail(tester, _trip(), height: 800);
    final ombrello = find.byKey(const Key('slot_row_v-ombrello'));
    await tester.scrollUntilVisible(
      ombrello,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(ombrello);
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: openBody,
      matching: find.byType(ProposedSlotsCard),
    );
    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    expect(tester.getTopLeft(card).dy, closeTo(listTop, 1));
  });

  testWidgets('"Presa" su una proposta da comprare, chiusa con ×2: resta '
      'fra le proposte e non torna "da comprare"', (tester) async {
    await pumpDetail(
      tester,
      _trip(extra: [_slot('u-sciarpa', 'Sciarpa', copies: 3, toBuy: true)]),
      slot: 'u-sciarpa',
    );

    expect(inOpen(find.text('Sciarpa')), findsOneWidget);
    await send(tester, 'Sciarpa rossa');
    verify(
      () =>
          rawAnalytics.logEvent('slot_bought', properties: {'level': 'useful'}),
    ).called(1);
    await tester.tap(find.byKey(const Key('slot_bar_close')));
    await tester.pumpAndSettle();

    final saved = lastSaved();
    final sciarpa = saved.aiResult!.slots!.firstWhere(
      (s) => s.id == 'u-sciarpa',
    );
    expect(sciarpa.toBuy, isFalse);
    expect(sciarpa.remaining, 2);
    expect(inRow('u-sciarpa', find.text('×2')), findsOneWidget);
    expect(
      toBuyEntriesOf([saved]).where((e) => e.slot.id == 'u-sciarpa'),
      isEmpty,
    );
  });

  testWidgets('"Aggiungi la tua" su un importante apre la sua card, senza X', (
    tester,
  ) async {
    await pumpDetail(tester, _trip());

    await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('slot_card_imp-giacca')),
        matching: openBody,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('slot_remove_imp-giacca')), findsNothing);
  });

  /// Le animazioni implicite in corsa fuori dall'AppBar. L'AppBar anima da
  /// sola l'ombra quando la lista le scorre sotto (tema Material, per tutta
  /// l'app): non è di questa pagina.
  List<Type> animatingOutsideAppBar() => [
    for (final e
        in find
            .byWidgetPredicate((w) => w is ImplicitlyAnimatedWidget)
            .evaluate())
      if (((e as StatefulElement).state as ImplicitlyAnimatedWidgetState)
              // ignore: invalid_use_of_protected_member
              .controller
              .isAnimating &&
          e.findAncestorWidgetOfExactType<AppBar>() == null)
        e.widget.runtimeType,
  ];

  testWidgets('con le animazioni disattivate nessun ticker dopo un pump', (
    tester,
  ) async {
    await pumpDetail(tester, _trip(), noAnimations: true);
    final list = find.byType(ListView);

    // Il tocco diretto, senza l'inchiostro del tocco (che ha il suo ticker).
    tester
        .widget<InkWell>(find.byKey(const Key('slot_row_u-magliette')))
        .onTap!();
    await tester.pump();
    expect(openBody, findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    // Al frame dopo è già in cima: un salto, non uno scorrimento.
    await tester.pump();
    expect(animatingOutsideAppBar(), isEmpty);
    final card = find.ancestor(
      of: openBody,
      matching: find.byType(ProposedSlotsCard),
    );
    expect(tester.getTopLeft(card).dy, closeTo(tester.getTopLeft(list).dy, 1));

    tester
        .widget<DsIconButton>(find.byKey(const Key('slot_bar_close')))
        .onPressed!();
    await tester.pump();
    expect(openBody, findsNothing);
    // L'ombra dell'AppBar può essere ancora in corsa dallo scorrimento di
    // prima: si guarda il resto.
    expect(animatingOutsideAppBar(), isEmpty);
    await tester.pump();
    expect(animatingOutsideAppBar(), isEmpty);
  });
}
