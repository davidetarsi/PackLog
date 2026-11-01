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
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_rapid_fire_bar.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
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
  }) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = slot == null ? '/trips/trip-1' : '/trips/trip-1?slot=$slot';
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

  final bar = find.byType(SlotRapidFireBar);
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

  group('aprire la barra', () {
    testWidgets('toccare un proposto la mette al posto di "Modifica valigia"', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      expect(cta, findsOneWidget);
      expect(bar, findsNothing);

      await openMagliette(tester);

      expect(bar, findsOneWidget);
      expect(cta, findsNothing);
      expect(find.text('Magliette · 5 da personalizzare'), findsOneWidget);
      expect(find.text('Es. 2 t-shirt nere'), findsOneWidget);
      expect(find.byType(RapidFireInput), findsOneWidget);
      expect(find.text('Da comprare'), findsWidgets);
    });

    testWidgets('"Aggiungi la tua" su un importante apre la barra', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      expect(find.text('Giacca invernale · 1 da personalizzare'), findsOne);
    });

    testWidgets('la X chiude la barra e torna "Modifica valigia"', (
      tester,
    ) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      await tester.tap(find.byKey(const Key('slot_bar_close')));
      await tester.pumpAndSettle();

      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
    });

    testWidgets('il tasto indietro chiude prima la barra, poi la pagina', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), fromHome: true);
      await openMagliette(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
      expect(find.byType(TripDetailScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsNothing);
    });

    testWidgets('?slot= la apre all\'avvio', (tester) async {
      await pumpDetail(tester, _trip(), slot: 'u-magliette');

      expect(bar, findsOneWidget);
      expect(find.text('Magliette · 5 da personalizzare'), findsOneWidget);
    });

    testWidgets('?slot= sconosciuto o già chiuso: ignorato in silenzio', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), slot: 'non-esiste');
      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('?slot= di un posto chiuso: ignorato in silenzio', (
      tester,
    ) async {
      await pumpDetail(tester, _trip(), slot: 'u-chiuso');
      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('casa di partenza sparita: niente barra e lo snack lo dice', (
      tester,
    ) async {
      when(() => houseRepo.getAllHouses()).thenAnswer((_) async => []);
      await pumpDetail(tester, _trip());

      await openMagliette(tester);

      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
      expect(find.text('La casa di partenza non c\'è più'), findsOneWidget);
    });

    testWidgets('?slot= con la casa sparita: niente barra e lo snack', (
      tester,
    ) async {
      when(() => houseRepo.getAllHouses()).thenAnswer((_) async => []);
      await pumpDetail(tester, _trip(), slot: 'u-magliette');

      expect(bar, findsNothing);
      expect(find.text('La casa di partenza non c\'è più'), findsOneWidget);
    });
  });

  group('riempire il posto', () {
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

      // La riga del posto si aggiorna sotto gli occhi, la barra resta.
      expect(inProposed(find.text('×3')), findsNWidgets(2));
      expect(find.byKey(Key('trip_item_${packed.id}')), findsOneWidget);
      expect(find.text('Magliette · 3 da personalizzare'), findsOneWidget);
      expect(bar, findsOneWidget);
    });

    testWidgets('senza numero l\'oggetto entra con una copia', (tester) async {
      await pumpDetail(tester, _trip());
      await openMagliette(tester);

      await send(tester, 'Camicia blu');

      expect(lastSaved().items.single.quantity, 1);
      expect(find.text('Magliette · 4 da personalizzare'), findsOneWidget);
    });

    testWidgets('"5 t-shirt" su ×3: il posto sparisce, la barra si chiude, '
        'l\'oggetto ha 5 copie', (tester) async {
      await pumpDetail(tester, _trip(magliette: 3));
      await openMagliette(tester);

      await send(tester, '5 t-shirt');

      final saved = lastSaved();
      expect(saved.items.single.quantity, 5);
      expect(
        saved.aiResult!.slots!
            .firstWhere((s) => s.id == 'u-magliette')
            .remaining,
        0,
      );
      expect(inProposed(find.text('Magliette')), findsNothing);
      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
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

    testWidgets('"Presa" dalla riga e poi un riempimento: slot_bought una '
        'volta', (tester) async {
      await pumpDetail(tester, withGiaccaToBuy());
      await tester.tap(find.byKey(const Key('slot_got_it_imp-giacca')));
      await tester.pumpAndSettle();

      await send(tester, 'Piumino nero');

      expectEvent('slot_filled', {'level': 'important', 'copies': 1}, 1);
      expectEvent('slot_bought', {'level': 'important'}, 1);
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

    testWidgets('slot_marked_to_buy dalla barra, e Annulla non ne emette '
        'altri', (tester) async {
      await pumpDetail(tester, _trip());
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('slot_bar_to_buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expectEvent('slot_marked_to_buy', {
        'level': 'important',
        'from': 'bar',
      }, 1);
      expectNoEvent('slot_bought');
    });
  });

  group('"Da comprare"', () {
    testWidgets('nella barra marca il posto, chiude la barra e propone '
        'Annulla', (tester) async {
      await pumpDetail(tester, _trip());
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('slot_bar_to_buy')));
      await tester.pumpAndSettle();

      expect(bar, findsNothing);
      expect(cta, findsOneWidget);
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

    testWidgets('"Annulla" della barra funziona dopo aver lasciato la '
        'pagina', (tester) async {
      await pumpDetail(tester, _trip(), fromHome: true);
      await tester.tap(find.byKey(const Key('slot_add_imp-giacca')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slot_bar_to_buy')));
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

    testWidgets('su un posto già "da comprare" la barra non lo ripropone', (
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

      expect(bar, findsOneWidget);
      expect(find.byKey(const Key('slot_bar_to_buy')), findsNothing);
    });
  });
}
