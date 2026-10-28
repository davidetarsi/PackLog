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
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/view/new_trip_screen.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// La modifica del viaggio apre una copia; se nel frattempo la valigia AI viene
/// salvata sul viaggio, il salvataggio della modifica non deve riportare la
/// copia vecchia (senza risposte AI).
void main() {
  setUpAll(() async {
    registerFallbackValue(
      TripModel(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
    'salvare la modifica non cancella la valigia AI salvata nel frattempo',
    (tester) async {
      final trip = TripModel(
        id: 'trip-1',
        name: 'Toscana',
        departureDateTime: DateTime(2026, 9, 12),
        returnDateTime: DateTime(2026, 9, 20),
        destinationLocation: LocationSuggestionModel(
          placeId: 'p',
          displayName: 'Siena, Italia',
          city: 'Siena',
        ),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      var stored = [trip];
      final tripRepo = MockTripRepository();
      final houseRepo = MockHouseRepository();
      final itemRepo = MockItemRepository();
      final analytics = MockCoreAnalyticsService();
      final sync = MockSyncOrchestrator();

      when(() => tripRepo.getAllTrips()).thenAnswer((_) async => stored);
      when(() => tripRepo.updateTrip(any())).thenAnswer((invocation) async {
        final updated = invocation.positionalArguments.first as TripModel;
        stored = [updated];
      });
      when(
        () => houseRepo.getAllHouses(),
      ).thenAnswer((_) async => <HouseModel>[]);
      when(() => analytics.trackTripUpdated()).thenAnswer((_) async {});
      when(() => sync.requestSync()).thenReturn(null);

      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
          syncOrchestratorProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(container.dispose);
      await container.read(tripNotifierProvider.future);

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
                  onPressed: () => context.push('/trips/trip-1/edit-info'),
                  child: const Text('apri'),
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'trips/:id/edit-info',
                builder: (_, state) =>
                    NewTripScreen(tripId: state.pathParameters['id']!),
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
      await _attendi(
        tester,
        () => find.byKey(const Key('open_edit')).evaluate().isNotEmpty,
      );

      // Si apre la modifica: la copia nasce senza valigia AI.
      await tester.tap(find.byKey(const Key('open_edit')));
      await tester.pumpAndSettle();
      await _attendi(
        tester,
        () => find.byKey(const Key('edit_trip_save')).evaluate().isNotEmpty,
      );

      // Mentre la modifica è aperta, la valigia AI viene salvata sul viaggio.
      stored = [
        trip.copyWith(aiSetup: const AiPackingSetup(houseId: 'casa-1')),
      ];
      container.invalidate(tripNotifierProvider);
      await container.read(tripNotifierProvider.future);

      // Poi l'utente cambia il nome e salva.
      await tester.enterText(
        find.byKey(const Key('new_trip_name')),
        'Toscana 2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit_trip_save')));
      await tester.pumpAndSettle();

      final salvato =
          verify(() => tripRepo.updateTrip(captureAny())).captured.single
              as TripModel;
      expect(salvato.name, 'Toscana 2');
      expect(salvato.aiSetup?.houseId, 'casa-1');
    },
  );
}

/// Timer reale: l'I/O di caricamento delle traduzioni non avanza con il clock finto.
Future<void> _attendi(WidgetTester tester, bool Function() condizione) async {
  for (var i = 0; i < 300 && !condizione(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pumpAndSettle();
  }
}
