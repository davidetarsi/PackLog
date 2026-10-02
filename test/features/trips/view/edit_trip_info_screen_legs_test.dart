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

/// Le tappe si aggiungono in creazione ma il dettaglio viaggio porta a
/// `edit-info`, non a `/trips/:id/edit`: se la sezione non vive anche qui, una
/// tappa sbagliata resta sbagliata per sempre — e il ramo `[]` del sync
/// ("l'utente ha rimosso le tappe") non è più raggiungibile dopo il primo
/// salvataggio.
void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;
  late MockCoreAnalyticsService analytics;
  late ProviderContainer container;
  late List<TripModel> stored;

  final trip = TripModel(
    id: 'trip-1',
    name: 'Toscana',
    departureDateTime: DateTime(2026, 9, 12),
    returnDateTime: DateTime(2026, 9, 20),
    legs: const [
      TripLeg(id: 'a', locationDisplayName: 'Firenze'),
      TripLeg(id: 'b', locationDisplayName: 'Siena'),
    ],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() async {
    // Il viaggio ha delle date, e `TripInfoForm._derivedName` le formatta con
    // `context.locale`: senza EasyLocalization montata il form esplode prima
    // ancora di arrivare alle tappe.
    registerFallbackValue(
      TripModel(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    // Una volta sola per file, non per test: come in sync_status_tile_test.dart.
    // Richiamarlo in ogni setUp() lascia il caricamento delle traduzioni
    // bloccato per sempre dal secondo test in poi — non un problema di
    // timing, la schermata resta vuota per sempre indipendentemente da
    // quanto a lungo si aspetta.
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
    when(
      () => houseRepo.getAllHouses(),
    ).thenAnswer((_) async => <HouseModel>[]);
    when(
      () => itemRepo.moveItemsToHouse(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => analytics.trackTripUpdated()).thenAnswer((_) async {});

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

    // Risolviamo prima di montare, com'è già risolto nell'app (keepAlive):
    // il caso opposto — dato che arriva dopo il mount — ha il suo test in
    // trip_edit_loading_test.dart.
    await container.read(tripNotifierProvider.future);
  });

  tearDown(() => container.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    // Viewport alto: il form viaggio è lungo e la sezione tappe sta in fondo,
    // sotto la CTA flottante. Con i 600px di default la X di una tappa non è
    // raggiungibile dal tap.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // GoRouter vero: la schermata chiude con `context.pop()` dopo il salvataggio
    // e la rotta annidata garantisce che ci sia qualcosa sotto da tornare.
    final router = GoRouter(
      initialLocation: '/trips/trip-1/edit-info',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'trips/:id/edit-info',
              builder: (_, state) =>
                  EditTripInfoScreen(tripId: state.pathParameters['id']!),
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
        // Delegates come in bootstrap.dart: GlobalMaterialLocalizations
        // inizializza i simboli di data di intl, senza i quali il nome
        // derivato del viaggio (DateFormat.yMd) esplode.
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
    // Il delegate di EasyLocalization carica il JSON con I/O reale: finché non
    // ha risolto, `Localizations` rende un SizedBox vuoto e la schermata non
    // esiste ancora nell'albero. pumpAndSettle da solo non fa avanzare l'async
    // vero, quindi diamo qualche giro di orologio reale.
    await waitForCondition(
      tester,
      () => find.byKey(const Key('trip_leg_row')).evaluate().isNotEmpty,
    );
  }

  group('EditTripInfoScreen — tappe', () {
    // Un solo testWidgets invece di due: ogni `pumpScreen` monta una nuova
    // EasyLocalization che rifà per intero il caricamento reale del JSON di
    // traduzione (il delegate non mantiene cache tra un mount e l'altro
    // nello stesso isolate). Un secondo mount nello stesso file non ha mai
    // completato quel caricamento, indipendentemente da quanto a lungo lo si
    // aspettava — non è un problema di timing, quindi la soluzione è montare
    // la schermata una volta sola e verificare entrambe le cose sullo stesso
    // albero.
    testWidgets('mostra le tappe e la rimozione le toglie dal viaggio', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('trip_leg_row')), findsNWidgets(2));
      expect(find.text('Firenze'), findsOneWidget);
      expect(find.text('Siena'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trip_leg_remove_a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip_leg_row')), findsOneWidget);

      // Per key, non per testo: qui EasyLocalization è montata davvero e
      // l'etichetta è tradotta.
      await tester.tap(find.byKey(const Key('edit_trip_info_save')));
      await tester.pumpAndSettle();

      final saved =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(saved.legs, hasLength(1));
      expect(saved.legs.single.id, 'b');
    });
  });
}

/// Timer reale, non l'orologio finto di `pumpAndSettle`: quando l'intera
/// suite trips gira in parallelo (~190 widget test) il carico di sistema fa
/// slittare l'I/O reale ben oltre un budget fisso breve. Il margine costa
/// nulla quando la condizione si avvera al primo giro, come succede quasi
/// sempre girando questo file da solo.
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
