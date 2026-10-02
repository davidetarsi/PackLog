import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/view/edit_trip_items_screen.dart';
import 'package:pack_log/features/trips/view/widgets/trip_edit_placeholder.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';
import 'package:pack_log/shared/widgets/ds_error_state.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

/// Le schermate di modifica copiano il viaggio in uno stato locale: finché
/// quella copia non esiste devono mostrare qualcosa. Prima mostravano sempre
/// uno spinner, e la copia veniva tentata una volta sola in `initState` — se
/// il provider non aveva ancora finito di caricare, lo spinner girava per
/// sempre.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('tripEditPlaceholder', () {
    Future<void> pumpPlaceholder(
      WidgetTester tester,
      AsyncValue<List<TripModel>> tripsAsync, {
      bool isHydrated = false,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Consumer(
              builder: (context, ref, _) =>
                  tripEditPlaceholder(
                    context: context,
                    ref: ref,
                    title: 'Modifica',
                    tripsAsync: tripsAsync,
                    isHydrated: isHydrated,
                  ) ??
                  const Scaffold(body: Text('schermata vera')),
            ),
          ),
        ),
      );
    }

    testWidgets('in caricamento mostra lo spinner', (tester) async {
      await pumpPlaceholder(tester, const AsyncLoading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('in errore mostra l errore, non uno spinner infinito', (
      tester,
    ) async {
      await pumpPlaceholder(
        tester,
        AsyncError(Exception('boom'), StackTrace.empty),
      );

      expect(find.byType(DsErrorState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('viaggio inesistente offre di tornare indietro', (
      tester,
    ) async {
      // Il dato è arrivato e il viaggio non c'è: cancellato altrove, o link
      // vecchio. Riprovare non serve, uscire sì.
      await pumpPlaceholder(tester, const AsyncData(<TripModel>[]));

      expect(find.byType(DsEmptyState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a copia fatta lascia passare la schermata vera', (
      tester,
    ) async {
      await pumpPlaceholder(
        tester,
        const AsyncData(<TripModel>[]),
        isHydrated: true,
      );

      expect(find.text('schermata vera'), findsOneWidget);
    });
  });

  testWidgets(
    'il viaggio che arriva dopo il primo frame riempie la schermata',
    (tester) async {
      // Il caso che rompeva: provider ancora in caricamento al momento del
      // mount (avvio a freddo su un deep link, o invalidazione dopo un sync).
      final trip = TripModel(
        id: 'trip-1',
        name: 'Toscana',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final tripRepo = MockTripRepository();
      final houseRepo = MockHouseRepository();
      final itemRepo = MockItemRepository();
      final trips = Completer<List<TripModel>>();

      when(() => tripRepo.getAllTrips()).thenAnswer((_) => trips.future);
      when(
        () => houseRepo.getAllHouses(),
      ).thenAnswer((_) async => <HouseModel>[]);
      when(
        () => itemRepo.getItemsByHouseId(any()),
      ).thenAnswer((_) async => <ItemModel>[]);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          saveLocale: false,
          child: Builder(
            builder: (context) => ProviderScope(
              overrides: [
                tripRepositoryProvider.overrideWithValue(tripRepo),
                houseRepositoryProvider.overrideWithValue(houseRepo),
                itemRepositoryProvider.overrideWithValue(itemRepo),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: const EditTripItemsScreen(tripId: 'trip-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsWidgets,
        reason: 'finché i viaggi non arrivano non c è niente da modificare',
      );

      trips.complete([trip]);
      await tester.pumpAndSettle();

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'il viaggio è arrivato: la schermata deve costruirsi',
      );
      expect(find.byType(EditTripItemsScreen), findsOneWidget);
    },
  );
}
