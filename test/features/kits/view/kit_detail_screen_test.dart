import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  setUp(caricaCatalogoDelRepo);

  /// Un kit "Sci" nella casa di Milano, con le copie date (id oggetto →
  /// copie) e gli usi dati.
  Future<KitModel> makeKit(
    ScreenshotApp app,
    Map<String, int> copies, {
    List<String> activities = const [],
  }) async => (await app.tester.runAsync(() async {
    final repo = app.container.read(kitRepositoryProvider);
    final kit = await repo.createKit(
      houseId: kHomeId,
      name: 'Sci',
      activities: activities,
    );
    await repo.addItems(kit.id, copies);
    return kit;
  }))!;

  Future<ScreenshotApp> openKit(
    WidgetTester tester, {
    Map<String, int> copies = const {'item-0': 1, 'item-5': 2},
    List<String> activities = const ['ski'],
    Future<void> Function(ScreenshotApp app, KitModel kit)? prepare,
  }) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final kit = await makeKit(app, copies, activities: activities);
    if (prepare != null) await prepare(app, kit);
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}');
    return app;
  }

  testWidgets('mostra pillole d\'uso, oggetti con copie e spazio', (
    tester,
  ) async {
    final app = await openKit(tester);

    expect(find.text('Entra da solo nei viaggi con'), findsOneWidget);
    expect(find.text('Sci e neve'), findsOneWidget);
    expect(find.text('Nel kit · 2'), findsOneWidget);
    expect(find.text('T-shirt bianca'), findsOneWidget);
    expect(find.text('Costume da bagno'), findsOneWidget);
    expect(find.text('Armadio camera'), findsOneWidget);
    expect(find.text('Cassettiera'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Aggiungi oggetti'), findsOneWidget);
    expect(find.text('Metti in valigia…'), findsOneWidget);
    await app.finish();
  });

  testWidgets('una pillola imparata dice da dove viene', (tester) async {
    final app = await openKit(
      tester,
      prepare: (app, kit) => app.tester.runAsync(() async {
        final repo = app.container.read(kitRepositoryProvider);
        await repo.recordYes(kit.id, ['trekking']);
        await repo.recordYes(kit.id, ['trekking']);
        await repo.learnUse(kit.id, 'trekking');
      }),
    );

    expect(find.text('Trekking'), findsOneWidget);
    expect(
      find.text('«Trekking» l\'hai aggiunto dopo 2 sì in valigia.'),
      findsOneWidget,
    );
    await app.finish();
  });

  testWidgets(
    'Metti in valigia aggiunge gli oggetti al viaggio scelto con le copie del kit (massimo)',
    (tester) async {
      final app = await openKit(
        tester,
        // In casa: item-0 ×5, item-1 ×2, item-4 ×7, item-5 ×2.
        copies: const {'item-0': 3, 'item-1': 3, 'item-4': 3, 'item-5': 5},
        prepare: (app, _) => app.tester.runAsync(() async {
          final now = DateTime(2026, 11, 3);
          TripItem onTrip(String id, String name, int quantity) => TripItem(
            id: id,
            name: name,
            category: ItemCategory.vestiti,
            quantity: quantity,
            originHouseId: kHomeId,
          );
          await app.container
              .read(tripNotifierProvider.notifier)
              .addTrip(
                TripModel(
                  id: 'trip-kit',
                  name: 'Prova kit',
                  items: [
                    onTrip('item-0', 'T-shirt bianca', 4),
                    onTrip('item-5', 'Costume da bagno', 1),
                    onTrip('item-4', 'Calzini', 1),
                  ],
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }),
      );

      await app.tap(find.text('Metti in valigia…'));
      final row = find.byKey(const Key('trip_picker_trip-kit'));
      await tester.ensureVisible(row);
      await app.tap(row);

      final trip = (await app.tester.runAsync(
        () =>
            app.container.read(tripRepositoryProvider).getTripById('trip-kit'),
      ))!;
      final quantities = {for (final i in trip.items) i.id: i.quantity};
      expect(quantities, {
        // Il viaggio ne ha già 4, il kit 3: non scendono.
        'item-0': 4,
        // Il kit ne vuole 3 ma in casa ce ne sono 2.
        'item-1': 2,
        // Il kit ne vuole 5 ma in casa ce ne sono 2: salgono a 2.
        'item-5': 2,
        // Il viaggio ne ha 1, il kit 3: salgono a 3 (mai la somma, 4).
        'item-4': 3,
      });
      await app.finish();
    },
  );

  testWidgets('cancellare il kit lascia gli oggetti', (tester) async {
    final app = await openKit(tester);

    await app.tap(find.byKey(const Key('kit_delete')));
    expect(find.text('Gli oggetti restano in casa.'), findsOneWidget);
    await app.tap(find.text('Elimina').last);

    final kits = (await app.tester.runAsync(
      () => app.container.read(kitRepositoryProvider).watchKits(kHomeId).first,
    ))!;
    expect(kits, isEmpty);
    final houseItems = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    expect(houseItems.any((i) => i.id == 'item-0'), isTrue);
    expect(houseItems.any((i) => i.id == 'item-5'), isTrue);
    await app.finish();
  });
}
