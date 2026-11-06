import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/to_buy_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class TripModelFake extends Fake implements TripModel {}

AiSlot _slot(
  String id,
  String name, {
  AiSlotLevel level = AiSlotLevel.useful,
  bool toBuy = true,
  int remaining = 1,
  String? boughtLabel,
}) => AiSlot(
  id: id,
  type: 'type-$id',
  category: ItemCategory.vestiti,
  level: level,
  name: name,
  copies: remaining,
  remaining: remaining,
  addLabel: 'Aggiungi',
  toBuy: toBuy,
  boughtLabel: boughtLabel,
);

TripModel _trip(
  String id,
  String name,
  DateTime departure,
  List<AiSlot> slots,
) => TripModel(
  id: id,
  name: name,
  departureDateTime: departure,
  items: const [],
  luggages: const [],
  aiResult: AiPackingResult(
    generatedAt: DateTime(2026, 11),
    houseId: 'h1',
    slots: slots,
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late MockTripRepository repo;

  setUpAll(() => registerFallbackValue(TripModelFake()));

  setUp(() {
    repo = MockTripRepository();
  });

  Future<GoRouter> pumpScreen(
    WidgetTester tester,
    List<TripModel> trips, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => repo.getAllTrips()).thenAnswer((_) async => trips);
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);

    // Niente timer di aggiornamento pendente a fine test.
    final lifecycle = MockTripLifecycleService();
    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        tripLifecycleServiceProvider.overrideWithValue(lifecycle),
        tripRepositoryProvider.overrideWithValue(repo),
        coreAnalyticsServiceProvider.overrideWithValue(
          MockCoreAnalyticsService(),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
        itemRepositoryProvider.overrideWithValue(MockItemRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tripNotifierProvider.future);

    final router = GoRouter(
      initialLocation: '/trips/to-buy',
      routes: [
        GoRoute(path: '/trips/to-buy', builder: (_, _) => const ToBuyScreen()),
        GoRoute(
          path: '/trips/:id',
          builder: (_, state) => Scaffold(
            body: Text(
              'detail ${state.pathParameters['id']} '
              'slot=${state.uri.queryParameters['slot']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: Builder(
          builder: (context) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
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
    return router;
  }

  testWidgets('raggruppa per viaggio, con l\'importante prima', (tester) async {
    await pumpScreen(tester, [
      _trip('t2', 'Parigi', DateTime(2027, 3), [_slot('s3', 'Ombrello')]),
      _trip('t1', 'Seul', DateTime(2026, 12), [
        _slot('s1', 'Calzini', remaining: 3),
        _slot('s2', 'Giacca invernale', level: AiSlotLevel.important),
      ]),
    ]);

    expect(find.text('Da comprare'), findsOneWidget); // titolo
    final seul = tester.getTopLeft(find.text('Seul')).dy;
    final parigi = tester.getTopLeft(find.text('Parigi')).dy;
    expect(seul, lessThan(parigi));

    final giacca = tester.getTopLeft(find.text('Giacca invernale')).dy;
    final calzini = tester.getTopLeft(find.text('Calzini')).dy;
    expect(giacca, greaterThan(seul));
    expect(giacca, lessThan(calzini));
    expect(calzini, lessThan(parigi));

    expect(find.text('×3'), findsOneWidget);
    expect(find.text('Ho comprato'), findsNWidgets(3));
  });

  testWidgets('un posto chiuso non compare', (tester) async {
    await pumpScreen(tester, [
      _trip('t1', 'Seul', DateTime(2026, 12), [
        _slot('s1', 'Calzini'),
        _slot('s2', 'Giacca invernale', remaining: 0),
      ]),
    ]);

    expect(find.text('Calzini'), findsOneWidget);
    expect(find.text('Giacca invernale'), findsNothing);
  });

  testWidgets('"Presa" apre il viaggio sul posto', (tester) async {
    await pumpScreen(tester, [
      _trip('t1', 'Seul', DateTime(2026, 12), [_slot('s1', 'Calzini')]),
    ]);

    await tester.tap(find.byKey(const Key('slot_got_it_s1')));
    await tester.pumpAndSettle();

    expect(find.text('detail t1 slot=s1'), findsOneWidget);
  });

  testWidgets('nome lungo, X e azione restano leggibili a 320px', (
    tester,
  ) async {
    await pumpScreen(tester, [
      _trip('t1', 'Seul', DateTime(2026, 12), [
        _slot(
          's1',
          'Giacca tecnica impermeabile ultraleggera da trekking',
          boughtLabel: 'Comprata',
          remaining: 2,
        ),
      ]),
    ], width: 320);

    expect(find.byKey(const Key('slot_not_useful_s1')), findsOneWidget);
    expect(find.text('Comprata'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rimozione dell’ultima voce è annullabile e serializzata', (
    tester,
  ) async {
    when(() => repo.updateTrip(any())).thenAnswer((_) async {});
    await pumpScreen(tester, [
      _trip('t1', 'Seul', DateTime(2026, 12), [_slot('s1', 'Calzini')]),
    ]);

    await tester.tap(find.byKey(const Key('slot_not_useful_s1')));
    await tester.pumpAndSettle();
    expect(find.text('Calzini'), findsNothing);
    expect(find.text('Tolta Calzini'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('Calzini'), findsOneWidget);
    verify(() => repo.updateTrip(any())).called(2);
  });

  testWidgets('un errore di salvataggio mantiene la richiesta visibile', (
    tester,
  ) async {
    when(() => repo.updateTrip(any())).thenThrow(StateError('offline'));
    await pumpScreen(tester, [
      _trip('t1', 'Seul', DateTime(2026, 12), [_slot('s1', 'Calzini')]),
    ]);

    await tester.tap(find.byKey(const Key('slot_not_useful_s1')));
    await tester.pumpAndSettle();
    expect(find.text('Calzini'), findsOneWidget);
    expect(find.text('Errore di salvataggio'), findsOneWidget);
  });

  testWidgets('senza voci mostra lo stato vuoto', (tester) async {
    await pumpScreen(tester, [
      _trip('t1', 'Seul', DateTime(2026, 12), [
        _slot('s1', 'Calzini', toBuy: false),
      ]),
    ]);

    expect(find.text('Niente da comprare'), findsOneWidget);
  });
}
