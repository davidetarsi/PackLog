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
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_inventory_search.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_luggage_selector.dart';
import 'package:pack_log/features/trips/view/widgets/slots/trip_items_card.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_checkbox.dart';
import 'package:pack_log/shared/widgets/quantity_stepper.dart';

import '../../../helpers/memory_asset_loader.dart';

class _TripRepo extends Mock implements TripRepository {}

class _HouseRepo extends Mock implements HouseRepository {}

class _ItemRepo extends Mock implements ItemRepository {}

class _LuggageRepo extends Mock implements LuggageRepository {}

class _Lifecycle extends Mock implements TripLifecycleService {}

class _Analytics extends Mock implements CoreAnalyticsService {}

class _Sync extends Mock implements SyncOrchestrator {}

final _casa = HouseModel(
  id: 'h1',
  name: 'Casa',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _zaino = LuggageModel(
  id: 'l1',
  name: 'Zaino blu',
  sizeType: LuggageSize.cabinBaggage,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripItem _item(String id, String name, ItemCategory category) =>
    TripItem(id: id, name: name, category: category, quantity: 1);

TripModel _trip({
  List<TripItem>? items,
  AiPackingResult? aiResult,
  List<LuggageModel> luggages = const [],
}) => TripModel(
  id: 'trip-1',
  name: 'Seul',
  items:
      items ??
      [
        _item('i-aux', 'Aux bt', ItemCategory.elettronica),
        _item('i-cuscino', 'Cuscino aereo', ItemCategory.varie),
      ],
  luggages: luggages,
  aiResult: aiResult,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late _TripRepo tripRepo;
  late _HouseRepo houseRepo;
  late _ItemRepo itemRepo;
  late _LuggageRepo luggageRepo;
  late _Lifecycle lifecycle;
  late _Analytics analytics;
  late _Sync sync;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_trip());
  });

  setUp(() {
    tripRepo = _TripRepo();
    houseRepo = _HouseRepo();
    itemRepo = _ItemRepo();
    luggageRepo = _LuggageRepo();
    lifecycle = _Lifecycle();
    analytics = _Analytics();
    sync = _Sync();
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
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => [_zaino]);
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    TripModel trip, {
    bool firstReview = false,
  }) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/trips/trip-1',
      routes: [
        GoRoute(path: '/trips', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (_, _) => const Scaffold(key: Key('edit_items_page')),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) => TripDetailScreen(
            tripId: state.pathParameters['id']!,
            firstReview: firstReview,
          ),
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final cta = find.byKey(const Key('trip_detail_cta'));

  group('valigia a mano', () {
    testWidgets('manual_suitcase_is_editable', (tester) async {
      await pumpDetail(tester, _trip());

      // Spunta.
      await tester.tap(find.byType(DsCheckbox).first);
      await tester.pumpAndSettle();
      verify(
        () => tripRepo.setTripItemChecked('trip-1', 'i-aux', true),
      ).called(1);

      // Apre la scheda e toglie l'oggetto.
      await tester.tap(find.text('Cuscino aereo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai_pack_item_remove')));
      await tester.pumpAndSettle();
      final saved = verify(() => tripRepo.updateTrip(captureAny())).captured;
      expect((saved.last as TripModel).items.map((i) => i.id), ['i-aux']);

      // Cambia i bagagli.
      await tester.tap(find.text('Zaino blu'));
      await tester.pumpAndSettle();
      final withLuggage =
          verify(() => tripRepo.updateTrip(captureAny())).captured.last
              as TripModel;
      expect(withLuggage.luggages.map((l) => l.id), ['l1']);

      // Niente proposta: nessun evento della valigia AI.
      verifyNever(
        () => analytics.trackAiSuitcaseChanged(
          tripId: any(named: 'tripId'),
          counts: any(named: 'counts'),
          context: any(named: 'context'),
        ),
      );
      verifyNever(
        () => analytics.trackAiSlotRemoved(
          type: any(named: 'type'),
          level: any(named: 'level'),
        ),
      );
    });

    testWidgets('checkbox_write_failure_keeps_list_and_shows_feedback', (
      tester,
    ) async {
      when(
        () => tripRepo.setTripItemChecked(any(), any(), any()),
      ).thenThrow(StateError('write failed'));
      await pumpDetail(tester, _trip());

      await tester.tap(find.byType(DsCheckbox).first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Aux bt'), findsOneWidget);
      expect(find.text('Errore di salvataggio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('manual_and_ai_use_same_section', (tester) async {
      await pumpDetail(tester, _trip());
      expect(find.byType(SuitcaseItemsSection), findsOneWidget);
      expect(find.byType(PackLuggageSelector), findsOneWidget);
      expect(find.byType(PackInventorySearch), findsNothing);
      expect(find.text('Cosa manca'), findsNothing);
    });

    testWidgets('ai_suitcase_uses_the_same_section', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [
              AiSlot(
                id: 's1',
                type: 's1',
                category: ItemCategory.vestiti,
                level: AiSlotLevel.useful,
                name: 'Maglioni',
                copies: 1,
                remaining: 1,
                addLabel: 'Aggiungi',
              ),
            ],
          ),
        ),
      );
      expect(find.byType(SuitcaseItemsSection), findsOneWidget);
      expect(find.byType(PackInventorySearch), findsOneWidget);
    });

    testWidgets('old_ai_result_without_slots_shows_as_manual', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
          ),
        ),
      );
      expect(find.byType(SuitcaseItemsSection), findsOneWidget);
      expect(find.byType(PackInventorySearch), findsNothing);
      expect(find.byType(PackLuggageSelector), findsOneWidget);
      expect(find.text('0 di 2 in valigia'), findsOneWidget);
    });
  });

  ItemModel inv(String id, String name, int quantity) => ItemModel(
    id: id,
    houseId: 'h1',
    name: name,
    category: ItemCategory.varie,
    quantity: quantity,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('scheda dell oggetto', () {
    testWidgets('manual_item_sheet_shows_copies_and_stepper', (tester) async {
      when(
        () => itemRepo.getItemsByHouseId('h1'),
      ).thenAnswer((_) async => [inv('i-cuscino', 'Cuscino aereo', 3)]);
      final trip = _trip(
        items: [
          TripItem(
            id: 'i-cuscino',
            name: 'Cuscino aereo',
            category: ItemCategory.varie,
            quantity: 2,
            originHouseId: 'h1',
          ),
        ],
      );
      await pumpDetail(tester, trip);

      await tester.tap(find.text('Cuscino aereo'));
      await tester.pumpAndSettle();

      expect(find.byType(QuantityStepper), findsOneWidget);
      expect(find.textContaining('Ne hai 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.pumpAndSettle();
      final saved =
          verify(() => tripRepo.updateTrip(captureAny())).captured.last
              as TripModel;
      expect(saved.items.single.quantity, 3);
    });

    testWidgets('old_ai_without_slots_item_sheet_waits_house_items', (
      tester,
    ) async {
      // Nessuna ricerca osserva la casa: la scheda deve aspettarne gli oggetti.
      when(
        () => itemRepo.getItemsByHouseId('h1'),
      ).thenAnswer((_) async => [inv('i-cuscino', 'Cuscino aereo', 3)]);
      await pumpDetail(
        tester,
        _trip(
          items: [
            TripItem(
              id: 'i-cuscino',
              name: 'Cuscino aereo',
              category: ItemCategory.varie,
              quantity: 1,
              originHouseId: 'h1',
            ),
          ],
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
          ),
        ),
      );

      await tester.tap(find.text('Cuscino aereo'));
      await tester.pumpAndSettle();

      expect(find.byType(QuantityStepper), findsOneWidget);
      expect(find.textContaining('Ne hai 3'), findsOneWidget);
    });
  });

  group('Aggiungi oggetti', () {
    testWidgets('add_items_cta_for_all_suitcases: a mano', (tester) async {
      await pumpDetail(tester, _trip());
      expect(
        find.descendant(of: cta, matching: find.text('Aggiungi oggetti')),
        findsOneWidget,
      );
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_items_page')), findsOneWidget);
    });

    testWidgets('add_items_cta_for_all_suitcases: vuota', (tester) async {
      await pumpDetail(tester, _trip(items: const []));
      expect(find.byType(EmptySuitcase), findsOneWidget);
      expect(
        find.descendant(of: cta, matching: find.text('Aggiungi oggetti')),
        findsOneWidget,
      );
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_items_page')), findsOneWidget);
    });

    testWidgets('add_items_cta_for_all_suitcases: AI dopo la revisione', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [
              AiSlot(
                id: 's1',
                type: 's1',
                category: ItemCategory.vestiti,
                level: AiSlotLevel.useful,
                name: 'Maglioni',
                copies: 1,
                remaining: 1,
                addLabel: 'Aggiungi',
              ),
            ],
          ),
        ),
      );
      expect(
        find.descendant(of: cta, matching: find.text('Aggiungi oggetti')),
        findsOneWidget,
      );
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_items_page')), findsOneWidget);
    });

    testWidgets('first_review_keeps_done', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11),
            houseId: 'h1',
            slots: [
              AiSlot(
                id: 's1',
                type: 's1',
                category: ItemCategory.vestiti,
                level: AiSlotLevel.useful,
                name: 'Maglioni',
                copies: 1,
                remaining: 1,
                addLabel: 'Aggiungi',
              ),
            ],
          ),
        ),
        firstReview: true,
      );
      expect(
        find.descendant(of: cta, matching: find.text('Fatto')),
        findsOneWidget,
      );
      expect(find.text('Aggiungi oggetti'), findsNothing);
    });
  });
}
