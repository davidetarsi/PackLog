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
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_checkbox.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

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
}) => TripModel(
  id: 'trip-1',
  name: 'Seul',
  items: items ?? _items(),
  aiResult: withResult
      ? aiResult ??
            AiPackingResult(
              generatedAt: DateTime(2026, 11),
              houseId: 'h1',
              slots: [..._important(), ..._useful],
            )
      : null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
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
  });

  /// Con [fromHome] il dettaglio sta sopra una pagina di partenza: si può
  /// lasciarlo con `pop`. Torna il router.
  Future<GoRouter> pumpDetail(
    WidgetTester tester,
    TripModel trip, {
    bool fromHome = false,
  }) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    // Alta abbastanza da costruire tutta la lista.
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: fromHome ? '/home' : '/trips/trip-1',
      routes: [
        if (fromHome)
          GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) =>
              TripDetailScreen(tripId: state.pathParameters['id']!),
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
    if (fromHome) {
      unawaited(router.push('/trips/trip-1'));
      await tester.pumpAndSettle();
    }
    return router;
  }

  Finder inProposed(Finder finder) =>
      find.descendant(of: find.byType(ProposedSlotsCard), matching: finder);

  group('valigia fatta di posti', () {
    testWidgets('testata, legenda e posti come nel mockup', (tester) async {
      await pumpDetail(tester, _trip());

      expect(find.text('13 di 18 pronti'), findsOneWidget);
      expect(find.text('4 tue'), findsOneWidget);
      expect(find.text('9 proposte da PackLog'), findsOneWidget);
      expect(find.text('5 importanti da sistemare'), findsOneWidget);

      expect(find.byType(SuitcaseProgressHeader), findsOneWidget);
      expect(find.byType(ImportantSlotCard), findsNWidgets(4));
      expect(find.byType(ToBuySlotRow), findsOneWidget);
      expect(find.byType(ProposedSlotsCard), findsOneWidget);

      // La card: etichetta, nome, motivo, le due azioni testuali.
      expect(find.text('Importante'), findsNWidgets(5));
      expect(find.text('Giacca invernale'), findsOneWidget);
      expect(
        find.text('Fino a -7°: nell’armadio non c’è una giacca adatta.'),
        findsOneWidget,
      );
      expect(find.text('Aggiungi la tua'), findsNWidgets(4));
      expect(find.text('Presa'), findsOneWidget);
      expect(
        find.text('Proposti da PackLog · tocca per mettere i tuoi'),
        findsOneWidget,
      );
      // I proposti con le copie; finché si sistema niente caselle.
      expect(inProposed(find.text('Magliette')), findsOneWidget);
      expect(inProposed(find.text('×5')), findsOneWidget);
      expect(inProposed(find.byType(DsCheckbox)), findsNothing);

      // Gli oggetti dell'utente restano le righe di oggi.
      expect(find.byKey(const Key('trip_item_i-aux')), findsOneWidget);
      // Il gruppo conta posti aperti più oggetti: 5 importanti + 9 utili.
      expect(find.text('Vestiti · 14'), findsOneWidget);
    });

    testWidgets('"Da comprare" sposta la card fra le righe da comprare, '
        'Annulla la riporta', (tester) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_to_buy_imp-giacca')));
      await tester.pumpAndSettle();

      expect(find.byType(ImportantSlotCard), findsNWidgets(3));
      expect(find.byType(ToBuySlotRow), findsNWidgets(2));
      expect(find.text('Presa'), findsNWidgets(2));
      // La legenda non cambia: un "da comprare" resta da sistemare.
      expect(find.text('13 di 18 pronti'), findsOneWidget);
      expect(find.text('5 importanti da sistemare'), findsOneWidget);
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

    testWidgets('importanti chiusi: spunte e caselle sui proposti', (
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

      expect(find.text('1 di 13 in valigia'), findsOneWidget);
      expect(find.text('13 di 13 pronti'), findsNothing);
      expect(find.byType(ImportantSlotCard), findsNothing);
      expect(find.byType(ToBuySlotRow), findsNothing);
      expect(inProposed(find.byType(DsCheckbox)), findsNWidgets(9));

      await tester.tap(inProposed(find.byType(DsCheckbox)).first);
      await tester.pumpAndSettle();

      expect(find.text('2 di 13 in valigia'), findsOneWidget);
      final saved =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(
        saved.aiResult!.slots!.firstWhere((s) => s.id == 'u-maglioni').checked,
        isTrue,
      );
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
      expect(find.text('4 importanti da sistemare'), findsOneWidget);
      expect(savedSlot(tester, 'imp-giacca').removed, isTrue);
    });

    testWidgets('X su un importante da comprare: dialog, "Togli", la riga '
        'sparisce', (tester) async {
      await pumpDetail(tester, _trip());

      await tester.tap(find.byKey(const Key('slot_remove_imp-sciarpa')));
      await tester.pumpAndSettle();
      expect(find.text('Togli Sciarpa?'), findsOneWidget);

      await tester.tap(find.text('Togli'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('slot_to_buy_row_imp-sciarpa')),
        findsNothing,
      );
      expect(savedSlot(tester, 'imp-sciarpa').removed, isTrue);
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
      );

      expect(find.text('Sciarpa leggera'), findsNothing);
      expect(find.byKey(const Key('slot_row_u-sciarpa')), findsNothing);
      expect(find.text('Vestiti · 14'), findsOneWidget);
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
