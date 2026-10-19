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
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/view/edit_trip_info_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// Dopo "Riusa" il viaggio copia è senza date e la modifica è l'unico modo per
/// completarlo: uscire senza salvare non deve lasciare una copia vuota in giro,
/// mentre un salvataggio riuscito la deve conservare.
void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;
  late MockCoreAnalyticsService analytics;
  late ProviderContainer container;
  late List<TripModel> stored;

  /// Location a cui il bottone della radice fa `push`: cambia tra uno scenario
  /// e l'altro (con or senza `reuse=1`).
  late String openLocation;

  final trip = TripModel(
    id: 'trip-1',
    name: 'Toscana',
    departureDateTime: DateTime(2026, 9, 12),
    returnDateTime: DateTime(2026, 9, 20),
    legs: const [TripLeg(id: 'a', locationDisplayName: 'Firenze')],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() async {
    registerFallbackValue(
      TripModel(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    // Una sola inizializzazione per file, come negli altri test di trips/view.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    analytics = MockCoreAnalyticsService();
    stored = [trip];

    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => stored);
    when(() => tripRepo.updateTrip(any())).thenAnswer((invocation) async {
      final updated = invocation.positionalArguments.first as TripModel;
      stored = [updated];
    });
    when(() => tripRepo.deleteTrip(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      stored = stored.where((t) => t.id != id).toList();
      return true;
    });
    when(
      () => houseRepo.getAllHouses(),
    ).thenAnswer((_) async => <HouseModel>[]);
    when(
      () => itemRepo.moveItemsToHouse(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => analytics.trackTripUpdated()).thenAnswer((_) async {});
    when(() => analytics.trackTripDeleted()).thenAnswer((_) async {});

    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        houseRepositoryProvider.overrideWithValue(houseRepo),
        itemRepositoryProvider.overrideWithValue(itemRepo),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
        syncOrchestratorProvider.overrideWithValue(sync),
      ],
    );

    await container.read(tripNotifierProvider.future);
  });

  tearDown(() => container.dispose());

  /// Monta una radice con un bottone che fa `push` su [openLocation]: così c'è
  /// sempre una pagina sotto la schermata di modifica, come nell'app.
  Future<void> pumpRoot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_edit'),
                onPressed: () => context.push(openLocation),
                child: const Text('apri'),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'trips/:id/edit-info',
              builder: (_, state) => EditTripInfoScreen(
                tripId: state.pathParameters['id']!,
                discardOnExit: state.uri.queryParameters['reuse'] == '1',
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        child: Builder(
          builder: (context) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light,
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForCondition(
      tester,
      () => find.byKey(const Key('open_edit')).evaluate().isNotEmpty,
    );
  }

  /// Dalla radice apre [location] e attende che la schermata di modifica sia
  /// pronta.
  Future<void> openEdit(WidgetTester tester, String location) async {
    openLocation = location;
    await tester.tap(find.byKey(const Key('open_edit')));
    await tester.pumpAndSettle();
    await waitForCondition(
      tester,
      () => find.byKey(const Key('edit_trip_info_save')).evaluate().isNotEmpty,
    );
  }

  /// Riporta lo stato al viaggio intatto tra uno scenario e il successivo.
  Future<void> resetTrips() async {
    stored = [trip];
    clearInteractions(tripRepo);
    container.invalidate(tripNotifierProvider);
    await container.read(tripNotifierProvider.future);
  }

  // Un solo testWidgets: ogni mount di EasyLocalization in questo file non
  // completa più il caricamento delle traduzioni dal secondo in poi (stesso
  // limite documentato in edit_trip_info_screen_legs_test.dart). Gli scenari
  // girano in sequenza sullo stesso albero.
  testWidgets('uscita dopo Riusa: elimina la copia solo se non si salva', (
    tester,
  ) async {
    await pumpRoot(tester);

    // 1. Indietro dall'AppBar senza salvare: copia eliminata una sola volta.
    await openEdit(tester, '/trips/trip-1/edit-info?reuse=1');
    await tester.pageBack();
    await tester.pumpAndSettle();
    verify(() => tripRepo.deleteTrip('trip-1')).called(1);

    // 2. Indietro di sistema senza salvare: copia eliminata.
    await resetTrips();
    await openEdit(tester, '/trips/trip-1/edit-info?reuse=1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    verify(() => tripRepo.deleteTrip('trip-1')).called(1);

    // 3. Salvataggio riuscito: la copia resta, nessuna eliminazione.
    await resetTrips();
    await openEdit(tester, '/trips/trip-1/edit-info?reuse=1');
    await tester.tap(find.byKey(const Key('edit_trip_info_save')));
    await tester.pumpAndSettle();
    verify(() => tripRepo.updateTrip(any())).called(1);
    verifyNever(() => tripRepo.deleteTrip(any()));

    // 4. Senza reuse: uscire senza salvare non elimina niente.
    await resetTrips();
    await openEdit(tester, '/trips/trip-1/edit-info');
    await tester.pageBack();
    await tester.pumpAndSettle();
    verifyNever(() => tripRepo.deleteTrip(any()));
  });
}

/// Timer reale, non l'orologio finto di `pumpAndSettle`: l'I/O di caricamento
/// delle traduzioni non avanza con il solo clock fake.
Future<void> waitForCondition(
  WidgetTester tester,
  bool Function() condition, {
  int maxIterations = 300,
}) async {
  for (var i = 0; i < maxIterations && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pumpAndSettle();
  }
}
