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
import 'package:pack_log/features/trips/view/widgets/slots/trip_items_card.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_pop.dart';
import 'package:pack_log/shared/theme/theme.dart';

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

  Finder inUserItems(Finder finder) =>
      find.descendant(of: find.byType(ItemsCard), matching: finder);
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

  /// Quante volte la bolla è partita (un `SlotPop` che sta scoppiando).
  bool popping() =>
      find.byType(SlotPop).evaluate().any((e) => (e.widget as SlotPop).popping);

  testWidgets('"5 t-shirt" su ×3: la bolla scoppia, poi T-shirt ×5 fra gli '
      'oggetti dell\'utente e nessuna riga Magliette', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);

    await tester.enterText(find.byType(TextField), '5 t-shirt');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();
    expect(popping(), isTrue);
    expect(openBody, findsOneWidget);

    await tester.pumpAndSettle();

    expect(openBody, findsNothing);
    expect(bar, findsNothing);
    expect(find.byKey(const Key('slot_row_u-magliette')), findsNothing);
    expect(find.text('Magliette'), findsNothing);
    expect(inUserItems(find.text('T-shirt')), findsOneWidget);
    expect(inUserItems(find.text('×5')), findsOneWidget);
  });

  testWidgets('la bolla avvolge tutto il riquadro, sfondo compreso, anche '
      'per un importante', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);
    final panel = find.ancestor(of: openBody, matching: find.byType(SlotPop));
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.byType(DecoratedBox)),
      findsWidgets,
    );

    await tester.tap(find.byKey(const Key('slot_bar_close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: openBody, matching: find.byType(SlotPop)),
      findsOneWidget,
    );
  });

  testWidgets('"Da comprare" nella barra: bolla, proposta fuori dal '
      'dettaglio e fra i da comprare', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);

    await tester.tap(find.byKey(const Key('slot_bar_to_buy')));
    await tester.pump();
    await tester.pump();
    expect(popping(), isTrue);

    await tester.pumpAndSettle();

    expect(openBody, findsNothing);
    expect(bar, findsNothing);
    expect(find.byKey(const Key('slot_row_u-magliette')), findsNothing);
    expect(
      toBuyEntriesOf([lastSaved()]).where((e) => e.slot.id == 'u-magliette'),
      isNotEmpty,
    );
  });

  testWidgets('chiusura con copie che restano: niente bolla, gli oggetti '
      'volano alla loro riga', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);
    await send(tester, '2 t-shirt nere');

    await tester.tap(find.byKey(const Key('slot_bar_close')));
    await tester.pump();
    expect(popping(), isFalse);
    await tester.pump();
    await tester.pump(AppMotion.slow ~/ 2);

    // La riga vera e la sua copia in volo.
    expect(find.text('T-shirt nere'), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.text('T-shirt nere'), findsOneWidget);
    expect(inUserItems(find.text('T-shirt nere')), findsOneWidget);
  });

  testWidgets('"Cappello di lana" scritto da Magliette finisce nel gruppo '
      'della sua categoria', (tester) async {
    await pumpDetail(tester, _trip());
    await openMagliette(tester);
    await send(tester, 'Cappello di lana');

    await tester.tap(find.byKey(const Key('slot_bar_close')));
    await tester.pumpAndSettle();

    final felpaCard = find.ancestor(
      of: find.text('Felpa grigia'),
      matching: find.byType(ItemsCard),
    );
    final cappelloCard = find.ancestor(
      of: find.text('Cappello di lana'),
      matching: find.byType(ItemsCard),
    );
    expect(cappelloCard, findsOneWidget);
    expect(
      cappelloCard.evaluate().single.widget,
      isNot(felpaCard.evaluate().single.widget),
    );
  });

  testWidgets('con le animazioni disattivate la bolla e il volo non lasciano '
      'ticker', (tester) async {
    await pumpDetail(tester, _trip(), noAnimations: true);
    await openMagliette(tester);

    await tester.enterText(find.byType(TextField), '5 t-shirt');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(openBody, findsNothing);
    expect(inUserItems(find.text('T-shirt')), findsOneWidget);
    expect(find.text('T-shirt'), findsOneWidget);
  });
}
