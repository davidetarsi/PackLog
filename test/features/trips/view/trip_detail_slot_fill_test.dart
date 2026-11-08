import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../helpers/mock_suitcase_edits.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/providers/luggage_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_fill_sheet.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slots_section.dart';
import 'package:pack_log/features/trips/view/widgets/slots/trip_items_card.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockRawAnalytics extends Mock implements AppAnalyticsService {}

/// Registra gli oggetti creati dal Rapid Fire, senza toccare il database.
class _RecordingItemNotifier extends ItemNotifier {
  _RecordingItemNotifier([this.initialItems = const []]);

  final List<ItemModel> initialItems;
  final added = <ItemModel>[];
  Completer<void>? addGate;

  @override
  Future<List<ItemModel>> build(String houseId) async => initialItems;

  void changeQuantity(String id, int quantity) {
    state = AsyncData([
      for (final item in state.valueOrNull ?? const <ItemModel>[])
        item.id == id ? item.copyWith(quantity: quantity) : item,
    ]);
  }

  @override
  Future<void> addItem(ItemModel model, {bool categoryChosen = false}) async {
    await addGate?.future;
    added.add(model);
    state = AsyncData([...state.valueOrNull ?? const <ItemModel>[], model]);
  }
}

class _EmptyLuggageNotifier extends LuggageNotifier {
  @override
  Future<List<LuggageModel>> build() async => const [];
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
  int? remaining,
  bool toBuy = false,
}) => AiSlot(
  id: id,
  type: id,
  category: category,
  level: level,
  name: name,
  copies: copies,
  remaining: remaining ?? copies,
  addLabel: 'Aggiungi la tua',
  toBuy: toBuy,
);

TripModel _trip({int magliette = 5, String houseId = 'h1'}) => TripModel(
  id: 'trip-1',
  name: 'Seul',
  items: const [],
  aiResult: AiPackingResult(
    generatedAt: DateTime(2026, 11),
    houseId: houseId,
    slots: [
      _slot('imp-giacca', 'Giacca invernale', level: AiSlotLevel.important),
      _slot('u-maglioni', 'Maglioni caldi', copies: 3),
      _slot('u-magliette', 'Magliette', copies: magliette),
      _slot('u-chiuso', 'Pigiama', remaining: 0),
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
  late GoRouter router;

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

  /// Con [fromHome] la pagina di dettaglio sta sopra una pagina di partenza,
  /// così si può tornare indietro.
  Future<void> pumpDetail(
    WidgetTester tester,
    TripModel trip, {
    String? slot,
    bool fromHome = false,
    bool firstReview = false,
  }) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = slot == null
        ? '/trips/trip-1${firstReview ? '?review=1' : '/needs'}'
        : '/trips/trip-1/needs?slot=$slot';
    router = GoRouter(
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
            firstReview: state.uri.queryParameters['review'] == '1',
          ),
        ),
        GoRoute(
          path: '/trips/:id/needs',
          builder: (context, state) => TripDetailScreen(
            tripId: state.pathParameters['id']!,
            showNeeds: true,
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
          tripLifecycleServiceProvider.overrideWithValue(lifecycle),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
          analyticsServiceProvider.overrideWithValue(rawAnalytics),
          syncOrchestratorProvider.overrideWithValue(sync),
          luggageNotifierProvider.overrideWith(() => _EmptyLuggageNotifier()),
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

  Finder inProposed(Finder finder) =>
      find.descendant(of: find.byType(ProposedSlotsCard), matching: finder);

  final sheet = find.byType(SlotFillSheet);
  final cta = find.byKey(const Key('trip_detail_cta'));

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

  group('aprire il foglio', () {
    testWidgets('toccare un proposto apre il foglio con nome, copie e frase', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      expect(sheet, findsNothing);

      await openMagliette(tester);

      expect(sheet, findsOneWidget);
      expect(find.text('Magliette ×5'), findsOneWidget);
      expect(
        find.text(
          'La quantità che aggiungi viene scalata da quella richiesta. Puoi segnare da comprare ciò che manca.',
        ),
        findsOneWidget,
      );
      expect(find.text('Es. 2 t-shirt nere'), findsOneWidget);
      expect(find.byType(RapidFireInput), findsOneWidget);
      expect(find.byKey(const Key('slot_sheet_to_buy')), findsOneWidget);
      // La pagina dei bisogni non duplica l'azione della valigia principale.
      expect(cta, findsNothing);
    });

    testWidgets('con il foglio aperto nessuna riga della pagina è spenta', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      final page = find.byType(SlotsSection);
      expect(
        find.descendant(of: page, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(
        find.descendant(of: page, matching: find.byType(AnimatedOpacity)),
        findsNothing,
      );
      expect(find.byKey(const Key('slot_open_u-magliette')), findsNothing);
    });

    testWidgets('"Aggiungi la tua" su un importante apre il foglio', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      expect(sheet, findsOneWidget);
      expect(find.text('Giacca invernale ×1'), findsOneWidget);
    });

    testWidgets('la X chiude il foglio', (tester) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(find.byType(TripDetailScreen), findsOneWidget);
    });

    testWidgets('il tasto indietro chiude il foglio, poi la pagina', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), fromHome: true);
      await openMagliette(tester);

      // Il primo indietro può togliere la tastiera dal campo.
      for (var i = 0; i < 2 && sheet.evaluate().isNotEmpty; i++) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      expect(sheet, findsNothing);
      expect(find.byType(TripDetailScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsNothing);
    });

    testWidgets('?slot= lo apre all\'avvio', (tester) async {
      await pumpDetail(tester, _trip(), slot: 'u-magliette');

      expect(sheet, findsOneWidget);
      expect(find.text('Magliette ×5'), findsOneWidget);
    });

    testWidgets('?slot= sconosciuto o già chiuso: ignorato in silenzio', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), slot: 'non-esiste');
      expect(sheet, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('?slot= di un posto chiuso: ignorato in silenzio', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), slot: 'u-chiuso');
      expect(sheet, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('casa di partenza sparita: niente foglio e lo snack lo dice', (
      tester,
    ) async {
      when(() => houseRepo.getAllHouses()).thenAnswer((_) async => []);
      await pumpDetail(tester, _trip());

      await openMagliette(tester);

      expect(sheet, findsNothing);
      expect(find.text('La casa di partenza non c\'è più'), findsOneWidget);
    });

    testWidgets('?slot= con la casa sparita: niente foglio e lo snack', (
      tester,
    ) async {
      when(() => houseRepo.getAllHouses()).thenAnswer((_) async => []);
      await pumpDetail(tester, _trip(), slot: 'u-magliette');

      expect(sheet, findsNothing);
      expect(find.text('La casa di partenza non c\'è più'), findsOneWidget);
    });
  });

  group('riempire il posto', () {
    testWidgets('creazione in coda rifiuta copie non piu disponibili', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripDetailScreen)),
        listen: false,
      );
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final queue = container
          .read(tripNotifierProvider.notifier)
          .serializeEdit('trip-1', () => gate.future);
      await tester.pump();
      await openMagliette(tester);
      await send(tester, '3 T-shirt nuove');
      expect(itemNotifier.added.single.quantity, 3);
      itemNotifier.changeQuantity(itemNotifier.added.single.id, 1);
      await tester.pump();
      gate.complete();
      await queue;
      await tester.pumpAndSettle();

      verifyNever(() => tripRepo.updateTrip(any()));
      expect(container.read(tripNotifierProvider).value!.single.items, isEmpty);
      expect(
        container.read(itemNotifierProvider('h1')).value!.single.quantity,
        1,
      );
      expect(find.text('Magliette ×5'), findsOneWidget);
      expect(find.text('Errore di salvataggio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una seconda apertura usa il residuo committato', (
      tester,
    ) async {
      final commitA = Completer<void>();
      final startedA = Completer<void>();
      var writes = 0;
      when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {
        if (writes++ == 0) {
          startedA.complete();
          await commitA.future;
        }
      });
      itemNotifier = _RecordingItemNotifier([
        ItemModel(
          id: 'inventory-socks',
          houseId: 'h1',
          name: 'Calzini blu',
          category: ItemCategory.vestiti,
          quantity: 3,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await pumpDetail(tester, _trip(magliette: 3));
      await openMagliette(tester);

      await tester.enterText(find.byType(TextField).first, '2 T-shirt nuove');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await startedA.future;
      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();

      await openMagliette(tester);
      expect(find.text('Magliette ×3'), findsOneWidget);
      commitA.complete();
      await tester.pumpAndSettle();
      expect(find.text('Magliette ×1'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Calzini blu');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slot_open_inventory_search')));
      await tester.pumpAndSettle();
      expect(find.text('×3'), findsNWidgets(2));
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      final saved = lastSaved();
      expect(saved.items.map((item) => item.quantity), [2, 1]);
      expect(
        saved.aiResult!.slots!
            .firstWhere((slot) => slot.id == 'u-magliette')
            .remaining,
        0,
      );
      expect(writes, 2);
    });

    testWidgets('un fill fallito non completa il posto mentre è in attesa', (
      tester,
    ) async {
      final saveGate = Completer<void>();
      final started = Completer<void>();
      when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {
        started.complete();
        await saveGate.future;
        throw StateError('save failed');
      });
      await pumpDetail(tester, _trip(magliette: 2));
      await openMagliette(tester);

      await tester.enterText(find.byType(TextField).first, '2 T-shirt nuove');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await started.future;
      expect(find.text('Hai aggiunto tutte le copie richieste.'), findsNothing);

      saveGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Hai aggiunto tutte le copie richieste.'), findsNothing);
      expect(find.text('Magliette ×2'), findsOneWidget);
    });

    testWidgets('una creazione continua dopo chiusura e pop della route', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), fromHome: true);
      await openMagliette(tester);
      itemNotifier.addGate = Completer<void>();

      await tester.enterText(find.byType(TextField), 'T-shirt nuova');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsNothing);

      itemNotifier.addGate!.complete();
      await tester.pumpAndSettle();

      expect(itemNotifier.added, hasLength(1));
      final saved = lastSaved();
      expect(saved.items.single.id, itemNotifier.added.single.id);
      expect(
        saved.aiResult!.slots!
            .firstWhere((slot) => slot.id == 'u-magliette')
            .remaining,
        4,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un errore dopo la chiusura avvisa e conserva inventario', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), fromHome: true);
      await openMagliette(tester);
      itemNotifier.addGate = Completer<void>();
      when(
        () => tripRepo.updateTrip(any()),
      ).thenThrow(StateError('save failed'));

      await tester.enterText(find.byType(TextField), 'T-shirt nuova');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      itemNotifier.addGate!.complete();
      await tester.pumpAndSettle();

      expect(itemNotifier.added, hasLength(1));
      expect(find.text('Errore di salvataggio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"2 t-shirt nere" crea l\'oggetto, lo mette in valigia e il '
        'posto scende a ×3', (tester) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      await send(tester, '2 t-shirt nere');

      expect(itemNotifier.added, hasLength(1));
      expect(itemNotifier.added.single.houseId, 'h1');
      expect(itemNotifier.added.single.name, 'T-shirt nere');
      expect(itemNotifier.added.single.quantity, 2);

      final saved = lastSaved();
      final packed = saved.items.single;
      expect(packed.id, itemNotifier.added.single.id);
      expect(packed.name, 'T-shirt nere');
      expect(packed.quantity, 2);
      expect(packed.originHouseId, 'h1');
      expect(
        saved.aiResult!.slots!
            .firstWhere((s) => s.id == 'u-magliette')
            .remaining,
        3,
      );

      // Il foglio resta, con l'oggetto e le copie che mancano; la pagina dietro
      // ha già l'oggetto nel suo gruppo.
      expect(sheet, findsOneWidget);
      expect(find.text('Magliette ×3'), findsOneWidget);
      expect(find.text('T-shirt nere'), findsWidgets);
      expect(inProposed(find.text('×3')), findsNWidgets(2));
      expect(find.byKey(Key('trip_item_${packed.id}')), findsNothing);
      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();
      router.go('/trips/trip-1');
      await tester.pumpAndSettle();
      expect(find.byKey(Key('trip_item_${packed.id}')), findsOneWidget);
    });

    testWidgets('senza numero l\'oggetto entra con una copia', (tester) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      await send(tester, 'Camicia blu');

      expect(lastSaved().items.single.quantity, 1);
      expect(find.text('Magliette ×4'), findsOneWidget);
    });

    testWidgets('chiuso a mano: gli oggetti restano nei loro gruppi e il '
        'posto tiene le copie che mancano', (tester) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);
      await send(tester, '2 t-shirt nere');

      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      final packed = lastSaved().items.single;
      router.go('/trips/trip-1');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ItemsCard),
          matching: find.byKey(Key('trip_item_${packed.id}')),
        ),
        findsOneWidget,
      );
      router.go('/trips/trip-1/needs');
      await tester.pumpAndSettle();
      expect(inProposed(find.text('Magliette')), findsOneWidget);
      expect(inProposed(find.text('×3')), findsNWidgets(2));
    });

    testWidgets('"5 t-shirt" su ×3: il foglio resta e mostra completamento, '
        'sparisce, l\'oggetto ha 5 copie', (tester) async {
      await pumpDetail(tester, _trip(magliette: 3));
      await openMagliette(tester);

      await tester.enterText(find.byType(TextField), '5 t-shirt');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      expect(sheet, findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        find.text('Hai aggiunto tutte le copie richieste.'),
        findsOneWidget,
      );

      final saved = lastSaved();
      expect(saved.items.single.quantity, 5);
      expect(
        saved.aiResult!.slots!
            .firstWhere((s) => s.id == 'u-magliette')
            .remaining,
        0,
      );
      expect(sheet, findsOneWidget);
      await tester.tap(find.byKey(const Key('slot_sheet_done')));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(inProposed(find.text('Magliette')), findsNothing);
    });
  });

  group('eventi', () {
    void expectEvent(String name, Map<String, Object?> properties, int times) {
      verify(
        () => rawAnalytics.logEvent(name, properties: properties),
      ).called(times);
    }

    void expectNoEvent(String name) {
      verifyNever(
        () => rawAnalytics.logEvent(name, properties: any(named: 'properties')),
      );
    }

    TripModel withGiaccaToBuy() {
      final trip = _trip();
      final slots = [
        for (final s in trip.aiResult!.slots!)
          s.id == 'imp-giacca' ? s.copyWith(toBuy: true) : s,
      ];
      return trip.copyWith(aiResult: trip.aiResult!.copyWith(slots: slots));
    }

    testWidgets('slot_filled su un proposto, senza slot_bought', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      await send(tester, '2 t-shirt nere');

      expectEvent('slot_filled', {'level': 'useful', 'copies': 2}, 1);
      expectNoEvent('slot_bought');
    });

    testWidgets('"Presa" dalla riga apre il foglio e un riempimento è '
        'slot_bought, una volta', (tester) async {
      await pumpDetail(tester, withGiaccaToBuy());
      await tester.tap(find.byKey(const Key('slot_got_it_imp-giacca')));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);

      await send(tester, 'Piumino nero');

      expectEvent('slot_filled', {'level': 'important', 'copies': 1}, 1);
      expectEvent('slot_bought', {'level': 'important'}, 1);
    });

    testWidgets('Comprato collegando inventario conserva slot_bought', (
      tester,
    ) async {
      itemNotifier = _RecordingItemNotifier([
        ItemModel(
          id: 'inventory-jacket',
          houseId: 'h1',
          name: 'Piumino nero',
          category: ItemCategory.vestiti,
          quantity: 1,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await pumpDetail(tester, withGiaccaToBuy(), slot: 'imp-giacca');
      await tester.enterText(find.byType(TextField), 'Piumino nero');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slot_open_inventory_search')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      expectEvent('slot_bought', {'level': 'important'}, 1);
      expect(lastSaved().items.single.id, 'inventory-jacket');
      expect(itemNotifier.added, isEmpty);
    });

    testWidgets('?slot= su un proposto da comprare: aprire non lo modifica, '
        'e il riempimento è slot_bought', (tester) async {
      final trip = _trip();
      final slots = [
        for (final s in trip.aiResult!.slots!)
          s.id == 'u-magliette' ? s.copyWith(toBuy: true) : s,
      ];
      await pumpDetail(
        tester,
        trip.copyWith(aiResult: trip.aiResult!.copyWith(slots: slots)),
        slot: 'u-magliette',
      );

      expect(sheet, findsOneWidget);
      expect(tester.widget<SlotFillSheet>(sheet).slot.toBuy, isTrue);
      expect(find.byKey(const Key('slot_sheet_to_buy')), findsNothing);
      verifyNever(() => tripRepo.updateTrip(any()));

      await send(tester, 'Camicia blu');

      expectEvent('slot_bought', {'level': 'useful'}, 1);
      final saved = lastSaved();
      final slot = saved.aiResult!.slots!.firstWhere(
        (s) => s.id == 'u-magliette',
      );
      expect(slot.remaining, 4);
      expect(slot.toBuy, isTrue);
    });

    testWidgets('?slot= (dalla vista Da comprare) e un riempimento: '
        'slot_bought', (tester) async {
      await pumpDetail(tester, withGiaccaToBuy(), slot: 'imp-giacca');

      await send(tester, 'Piumino nero');

      expectEvent('slot_bought', {'level': 'important'}, 1);
    });

    testWidgets('un posto non "da comprare" aperto dalla card non è '
        'slot_bought', (tester) async {
      await pumpDetail(tester, _trip());
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      await send(tester, 'Piumino nero');

      expectEvent('slot_filled', {'level': 'important', 'copies': 1}, 1);
      expectNoEvent('slot_bought');
    });

    testWidgets('slot_marked_to_buy dalla card', (tester) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_to_buy_imp-giacca')));
      await tester.pumpAndSettle();

      expectEvent('slot_marked_to_buy', {
        'level': 'important',
        'from': 'card',
      }, 1);
    });

    testWidgets('slot_marked_to_buy dal foglio, e Annulla non ne emette '
        'altri', (tester) async {
      await pumpDetail(tester, _trip());
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('slot_sheet_to_buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expectEvent('slot_marked_to_buy', {
        'level': 'important',
        'from': 'sheet',
      }, 1);
      expectNoEvent('slot_bought');
    });
  });

  group('"Da comprare"', () {
    testWidgets('nel foglio marca il posto, lo chiude e propone Annulla', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('slot_sheet_to_buy')));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(find.text('Segnato da comprare'), findsOneWidget);
      expect(find.byType(ToBuySlotRow), findsOneWidget);
      expect(
        lastSaved().aiResult!.slots!
            .firstWhere((s) => s.id == 'imp-giacca')
            .toBuy,
        isTrue,
      );

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.byType(ToBuySlotRow), findsNothing);
      expect(find.byType(ImportantSlotCard), findsOneWidget);
    });

    testWidgets('"Annulla" funziona anche dopo aver lasciato la pagina', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), fromHome: true);

      await tester.tap(find.byKey(const Key('slot_to_buy_imp-giacca')));
      await tester.pumpAndSettle();
      expect(find.byType(ToBuySlotRow), findsOneWidget);
      expect(find.text('Segnato da comprare'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsNothing);
      clearInteractions(tripRepo);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      final undone = lastSaved();
      expect(
        undone.aiResult!.slots!.firstWhere((s) => s.id == 'imp-giacca').toBuy,
        isFalse,
      );
    });

    testWidgets('ripristino in coda limita le copie allo stock rimasto', (
      tester,
    ) async {
      var stored = _trip().copyWith(
        items: [
          TripItem(
            id: 'inventory-tee',
            name: 'T-shirt bianca',
            category: ItemCategory.vestiti,
            quantity: 2,
            originHouseId: 'h1',
          ),
        ],
      );
      final undoGate = Completer<void>();
      final restoreStarted = Completer<void>();
      addTearDown(() {
        if (!undoGate.isCompleted) undoGate.complete();
      });
      var writes = 0;
      when(() => tripRepo.updateTrip(any())).thenAnswer((call) async {
        final next = call.positionalArguments.first as TripModel;
        writes++;
        if (writes == 2) {
          restoreStarted.complete();
          await undoGate.future;
        }
        stored = next;
      });
      itemNotifier = _RecordingItemNotifier([
        ItemModel(
          id: 'inventory-tee',
          houseId: 'h1',
          name: 'T-shirt bianca',
          category: ItemCategory.vestiti,
          quantity: 3,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);

      await pumpDetail(tester, stored, firstReview: true);
      when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [stored]);
      await tester.tap(find.byKey(const Key('trip_item_remove_inventory-tee')));
      await tester.pumpAndSettle();
      expect(stored.items, isEmpty);

      await tester.tap(find.text('Annulla'));
      await tester.pump();
      await restoreStarted.future;

      // Durante il salvataggio dell'Undo, la UI vede ancora il viaggio
      // senza la riga e propone erroneamente tutte e tre le copie.
      router.go('/trips/trip-1/needs?slot=u-magliette');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'T-shirt bianca');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerca nel tuo inventario'));
      await tester.pumpAndSettle();
      expect(find.text('×3'), findsNWidgets(2));
      await tester.tap(find.text('Aggiungi'));
      await tester.pump();

      undoGate.complete();
      await tester.pumpAndSettle();

      expect(writes, 3);
      expect(stored.items.single.quantity, 3);
      expect(stored.items.single.quantity, lessThanOrEqualTo(3));
      expect(
        stored.aiResult!.slots!
            .firstWhere((slot) => slot.id == 'u-magliette')
            .remaining,
        4,
      );
    });

    testWidgets('"Annulla" del foglio funziona dopo aver lasciato la '
        'pagina', (tester) async {
      await pumpDetail(tester, _trip(), fromHome: true);
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slot_sheet_to_buy')));
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      clearInteractions(tripRepo);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(
        lastSaved().aiResult!.slots!
            .firstWhere((s) => s.id == 'imp-giacca')
            .toBuy,
        isFalse,
      );
    });

    testWidgets('su un posto già "da comprare" il foglio non lo ripropone', (
      tester,
    ) async {
      final trip = _trip();
      final slots = [
        for (final s in trip.aiResult!.slots!)
          s.id == 'imp-giacca' ? s.copyWith(toBuy: true) : s,
      ];
      await pumpDetail(
        tester,
        trip.copyWith(aiResult: trip.aiResult!.copyWith(slots: slots)),
      );

      await tester.tap(find.byKey(const Key('slot_got_it_imp-giacca')));
      await tester.pumpAndSettle();

      expect(sheet, findsOneWidget);
      expect(find.byKey(const Key('slot_sheet_to_buy')), findsNothing);
    });
  });
}
