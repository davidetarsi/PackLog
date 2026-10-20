import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/auth/auth_repository.dart';
import 'package:pack_log/core/auth/auth_state.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trips_screen.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/trip_album.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:pack_log/shared/widgets/skeleton/skeleton.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// Il build del notifier chiede al servizio di ciclo di vita le transizioni di
/// stato: qui niente timer di aggiornamento pendente a fine test.
class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class _FakeAuthRepository implements AuthRepository {
  @override
  AuthState get currentAuthState => const AuthState.unauthenticated();

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

final _now = DateTime.now();

TripModel _trip(
  String id,
  String name, {
  DateTime? departure,
  DateTime? returnAt,
  bool isSaved = false,
  String? destinationHouseId,
}) {
  return TripModel(
    id: id,
    name: name,
    departureDateTime: departure,
    returnDateTime: returnAt,
    isSaved: isSaved,
    destinationHouseId: destinationHouseId,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

/// Viaggio in corso: prima cartolina della pila.
final _active = _trip(
  'active',
  'Viaggio in corso',
  departure: _now.subtract(const Duration(days: 2)),
  returnAt: _now.add(const Duration(days: 3)),
);

final _soon = _trip(
  'future-1',
  'Viaggio a marzo',
  departure: _now.add(const Duration(days: 30)),
  returnAt: _now.add(const Duration(days: 37)),
);

final _later = _trip(
  'future-2',
  'Viaggio a luglio',
  departure: _now.add(const Duration(days: 90)),
  returnAt: _now.add(const Duration(days: 97)),
);

final _pastSaved = _trip(
  'past-saved',
  'Viaggio salvato',
  departure: DateTime(2025, 3, 1),
  returnAt: DateTime(2025, 3, 8),
  isSaved: true,
);

final _past = _trip(
  'past',
  'Viaggio passato',
  departure: DateTime(2025, 6, 1),
  returnAt: DateTime(2025, 6, 5),
);

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;
  late MockCoreAnalyticsService analytics;
  late MockSyncOrchestrator sync;
  late MockTripLifecycleService lifecycle;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(_active);
  });

  setUp(() {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    analytics = MockCoreAnalyticsService();
    sync = MockSyncOrchestrator();
    lifecycle = MockTripLifecycleService();

    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);

    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => []);
    when(() => analytics.trackTripDuplicated()).thenAnswer((_) async {});
    when(() => sync.requestSync()).thenReturn(null);
    when(
      () => itemRepo.moveItemsToHouse(any(), any(), any()),
    ).thenAnswer((_) async {});
  });

  /// Monta la schermata su [location] e restituisce il router, per navigare
  /// mentre la schermata è già montata.
  Future<GoRouter> pumpScreen(
    WidgetTester tester, {
    required List<TripModel> trips,
    List<HouseModel> houses = const [],
    Future<List<TripModel>>? tripsFuture,
    String location = '/trips',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(
      () => tripRepo.getAllTrips(),
    ).thenAnswer((_) => tripsFuture ?? Future.value(trips));
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => houses);

    final container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        houseRepositoryProvider.overrideWithValue(houseRepo),
        itemRepositoryProvider.overrideWithValue(itemRepo),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
        syncOrchestratorProvider.overrideWithValue(sync),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        tripLifecycleServiceProvider.overrideWithValue(lifecycle),
        totalUnsyncedCountProvider.overrideWith((ref) async => 0),
      ],
    );
    addTearDown(container.dispose);
    if (tripsFuture == null) {
      await container.read(tripNotifierProvider.future);
    }
    await container.read(houseNotifierProvider.future);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/trips', builder: (_, _) => const TripsScreen()),
        GoRoute(
          path: '/trips/:id',
          builder: (_, state) =>
              Scaffold(body: Text('trip-detail ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/trips/:id/edit-info',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                const Text('edit-info'),
                Text('path=${state.uri.path}'),
                Text('reuse=${state.uri.queryParameters['reuse']}'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (_, state) =>
              Scaffold(body: Text('edit-items ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/new-trip',
          builder: (_, _) => const Scaffold(body: Text('new-trip')),
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
    if (tripsFuture == null) {
      await tester.pumpAndSettle();
    } else {
      // In caricamento lo shimmer non si ferma: niente pumpAndSettle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    return router;
  }

  /// Cartolina in cima della pila che mostra il viaggio di nome [name].
  Finder topCard(String name) => find.descendant(
    of: find.byKey(const Key('postcard_pile_top')),
    matching: find.text(name),
  );

  Future<void> tapFilter(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('TripsScreen', () {
    testWidgets('mostra tre filtri neutri e nessun filtro Tutto', (
      tester,
    ) async {
      await pumpScreen(tester, trips: [_active, _soon, _pastSaved, _past]);

      expect(find.text('Prossimi'), findsOneWidget);
      expect(find.text('Passati'), findsOneWidget);
      expect(find.text('Salvati'), findsOneWidget);
      expect(find.text('Tutto'), findsNothing);
    });

    testWidgets('Prossimi mostra la pila con in cima il viaggio in corso', (
      tester,
    ) async {
      await pumpScreen(tester, trips: [_soon, _later, _pastSaved, _active]);

      expect(find.byKey(const Key('postcard_pile')), findsOneWidget);
      final top = find.byKey(const Key('postcard_pile_top'));
      expect(
        find.descendant(of: top, matching: find.text('Viaggio in corso')),
        findsWidgets,
      );
      expect(
        find.descendant(of: top, matching: find.text('Viaggio a marzo')),
        findsNothing,
      );
    });

    testWidgets('focus sulla rotta mette in cima il terzo prossimo viaggio', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        trips: [_soon, _later, _active],
        location: '/trips?focus=future-2',
      );

      expect(topCard('Viaggio a luglio'), findsWidgets);
      expect(topCard('Viaggio in corso'), findsNothing);
    });

    testWidgets(
      'focus arrivato in ritardo, dopo il caricamento, mette in cima il viaggio',
      (tester) async {
        final completer = Completer<List<TripModel>>();
        await pumpScreen(
          tester,
          trips: const [],
          tripsFuture: completer.future,
          location: '/trips?focus=future-2',
        );

        completer.complete([_soon, _later, _active]);
        await tester.pumpAndSettle();

        expect(topCard('Viaggio a luglio'), findsWidgets);
      },
    );

    testWidgets(
      'focus su una rotta già aperta, da Passati, passa su Prossimi',
      (tester) async {
        final router = await pumpScreen(
          tester,
          trips: [_soon, _later, _active, _past],
        );
        await tapFilter(tester, 'Passati');
        expect(find.byType(TripAlbum), findsOneWidget);

        router.go('/trips?focus=future-2');
        await tester.pumpAndSettle();

        expect(find.byType(TripAlbum), findsNothing);
        expect(topCard('Viaggio a luglio'), findsWidgets);
      },
    );

    testWidgets(
      'il focus già portato in cima non riporta la pila indietro dopo uno swipe',
      (tester) async {
        final router = await pumpScreen(
          tester,
          trips: [_soon, _later, _active],
          location: '/trips?focus=future-2',
        );
        await tester.drag(
          find.byKey(const Key('postcard_pile')),
          const Offset(300, 0),
        );
        await tester.pumpAndSettle();
        expect(topCard('Viaggio a marzo'), findsWidgets);

        router.go('/trips?focus=future-2');
        await tester.pumpAndSettle();

        expect(topCard('Viaggio a marzo'), findsWidgets);
        expect(topCard('Viaggio a luglio'), findsNothing);
      },
    );

    testWidgets('focus su un id che non è tra i prossimi non sposta la pila', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        trips: [_soon, _later, _active],
        location: '/trips?focus=non-esiste',
      );

      expect(topCard('Viaggio in corso'), findsWidgets);
    });

    testWidgets(
      'la cartolina in cima mostra il nome della casa di destinazione',
      (tester) async {
        await pumpScreen(
          tester,
          trips: [
            _trip(
              'house-trip',
              'Vacanza',
              departure: _now.add(const Duration(days: 30)),
              returnAt: _now.add(const Duration(days: 37)),
              destinationHouseId: 'house-1',
            ),
          ],
          houses: [
            HouseModel(
              id: 'house-1',
              name: 'Baita dei nonni',
              createdAt: DateTime(2025),
              updatedAt: DateTime(2025),
            ),
          ],
        );

        expect(
          find.descendant(
            of: find.byKey(const Key('postcard_pile_top')),
            matching: find.text('Baita dei nonni'),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      "Passati mostra due cartoline dell'album e un gruppo per anno",
      (tester) async {
        await pumpScreen(tester, trips: [_active, _soon, _pastSaved, _past]);

        await tapFilter(tester, 'Passati');

        expect(find.byKey(const Key('album_postcard_past')), findsOneWidget);
        expect(
          find.byKey(const Key('album_postcard_past-saved')),
          findsOneWidget,
        );
        expect(find.byType(DsGroupHeader), findsOneWidget);
        expect(find.byType(TripAlbum), findsOneWidget);
      },
    );

    testWidgets('Salvati mostra solo i viaggi salvati', (tester) async {
      await pumpScreen(tester, trips: [_active, _pastSaved, _past]);

      await tapFilter(tester, 'Salvati');

      expect(
        find.byKey(const Key('album_postcard_past-saved')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('album_postcard_past')), findsNothing);
      expect(find.byKey(const Key('album_postcard_active')), findsNothing);
    });

    testWidgets('Riusa chiama reuseTrip e porta a edit-info con reuse=1', (
      tester,
    ) async {
      when(() => tripRepo.reuseTrip(any())).thenAnswer((_) async => 'copy-1');
      await pumpScreen(tester, trips: [_past]);

      await tapFilter(tester, 'Passati');
      await tester.tap(find.byKey(const Key('album_reuse_past')));
      await tester.pumpAndSettle();

      verify(() => tripRepo.reuseTrip('past')).called(1);
      expect(find.text('edit-info'), findsOneWidget);
      expect(find.text('path=/trips/copy-1/edit-info'), findsOneWidget);
      expect(find.text('reuse=1'), findsOneWidget);
    });

    testWidgets(
      'senza prossimi ma con un passato, Prossimi mostra lo stato vuoto con la CTA',
      (tester) async {
        await pumpScreen(tester, trips: [_past]);

        expect(find.byType(DsEmptyState), findsOneWidget);
        expect(find.text('Nessun viaggio in programma'), findsOneWidget);

        await tester.tap(find.text('Nuovo viaggio'));
        await tester.pumpAndSettle();

        expect(find.text('new-trip'), findsOneWidget);
      },
    );

    testWidgets('Salvati vuoto mostra il suggerimento per salvare', (
      tester,
    ) async {
      await pumpScreen(tester, trips: [_past]);

      await tapFilter(tester, 'Salvati');

      expect(find.text('Nessun viaggio salvato'), findsOneWidget);
      expect(
        find.text('Tieni premuto un viaggio e scegli Salva per riusarlo'),
        findsOneWidget,
      );
    });
    testWidgets(
      'durante il caricamento i filtri compaiono una sola volta, con la sagoma',
      (tester) async {
        final completer = Completer<List<TripModel>>();
        await pumpScreen(
          tester,
          trips: const [],
          tripsFuture: completer.future,
        );
        expect(find.byType(SkeletonTripsBody), findsOneWidget);
        expect(find.text('Prossimi'), findsOneWidget);
        expect(find.text('Passati'), findsOneWidget);
        expect(find.text('Salvati'), findsOneWidget);
        // Una sola sagoma: la cartolina, senza pillole placeholder.
        expect(find.byType(SkeletonBox), findsOneWidget);

        completer.complete([_active]);
        await tester.pumpAndSettle();

        expect(find.byType(SkeletonTripsBody), findsNothing);
        expect(find.byKey(const Key('postcard_pile')), findsOneWidget);
      },
    );
  });
}
