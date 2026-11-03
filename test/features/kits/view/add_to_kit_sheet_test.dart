import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';
import 'package:pack_log/shared/widgets/ds_floating_bar.dart';
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

  /// La casa aperta; [prepare] scrive i kit prima di aprirla, perché una
  /// scrittura con la riga dei kit già in ascolto non si assesta nel test.
  Future<ScreenshotApp> openHouse(
    WidgetTester tester, {
    Future<void> Function(KitRepository repo)? prepare,
  }) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    if (prepare != null) {
      await app.tester.runAsync(
        () => prepare(app.container.read(kitRepositoryProvider)),
      );
    }
    await app.go('/');
    await app.push('/houses/$kHomeId');
    return app;
  }

  /// Seleziona Calzini e Jeans blu, e apre il foglio "In un kit".
  Future<void> selectTwoAndOpenSheet(ScreenshotApp app) async {
    await app.longPress(find.text('Calzini'));
    await app.tap(find.text('Jeans blu'));
    await app.tap(find.byKey(const Key('selection_kit')));
  }

  Future<List<KitModel>> kitsOf(ScreenshotApp app) async =>
      (await app.tester.runAsync(
        () =>
            app.container.read(kitRepositoryProvider).watchKits(kHomeId).first,
      ))!;

  testWidgets(
    'la barra di selezione è Sposta · In un kit · In viaggio · Elimina',
    (tester) async {
      final app = await openHouse(tester);
      await app.longPress(find.text('Calzini'));

      final bar = tester.widget<DsFloatingBar>(find.byType(DsFloatingBar));
      expect(bar.children.map((c) => c.key), const [
        Key('selection_move'),
        Key('selection_kit'),
        Key('selection_trip'),
        Key('selection_delete'),
      ]);
      expect(find.text('In un kit'), findsOneWidget);
      await app.finish();
    },
  );

  testWidgets('In un kit apre il foglio col titolo plurale', (tester) async {
    final app = await openHouse(
      tester,
      prepare: (repo) =>
          repo.createKit(houseId: kHomeId, name: 'Sci', activities: ['ski']),
    );
    await selectTwoAndOpenSheet(app);

    expect(find.text('Metti 2 oggetti in un kit'), findsOneWidget);
    expect(
      find.text('Restano dove sono: il kit li tiene insieme.'),
      findsOneWidget,
    );
    expect(find.text('Nuovo kit'), findsOneWidget);
    expect(find.byKey(const Key('add_to_kit_new')), findsOneWidget);
    expect(find.text('Sci'), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'scegliere un kit aggiunge gli oggetti selezionati e chiude la selezione',
    (tester) async {
      final app = await openHouse(
        tester,
        prepare: (repo) async {
          final kit = await repo.createKit(houseId: kHomeId, name: 'Sci');
          await repo.addItems(kit.id, {'item-1': 3});
        },
      );
      await selectTwoAndOpenSheet(app);
      await app.tap(
        find.byKey(Key('add_to_kit_${(await kitsOf(app)).single.id}')),
      );

      final saved = (await kitsOf(app)).single;
      expect(
        {for (final i in saved.items) i.itemId: i.copies},
        {
          // Quello già nel kit tiene le sue copie.
          'item-1': 3,
          'item-4': 1,
        },
      );
      expect(find.byType(DsFloatingBar), findsNothing);
      expect(find.textContaining('selezionat'), findsNothing);

      // Gli oggetti restano nel loro spazio.
      final moved = (await app.tester.runAsync(
        () => app.container.read(itemRepositoryProvider).getItemById('item-4'),
      ))!;
      expect(moved.houseId, kHomeId);
      expect(moved.spaceId, 'space-cassettiera');
      await app.finish();
    },
  );

  testWidgets('Nuovo kit apre l\'editor con gli oggetti già dentro', (
    tester,
  ) async {
    final app = await openHouse(tester);
    await selectTwoAndOpenSheet(app);
    await app.tap(find.byKey(const Key('add_to_kit_new')));

    expect(find.text('Nuovo kit'), findsWidgets);
    expect(find.text('Nel kit · 2'), findsOneWidget);
    expect(find.text('Calzini'), findsOneWidget);
    expect(find.text('Jeans blu'), findsOneWidget);

    await app.enterText(find.byKey(const Key('kit_name_field')), 'Mare');
    await app.tap(find.text('Salva'));

    final saved = (await kitsOf(app)).single;
    expect(saved.name, 'Mare');
    expect(saved.items.map((i) => i.itemId).toSet(), {'item-1', 'item-4'});
    // Tornati in casa la selezione è chiusa.
    expect(find.byType(DsFloatingBar), findsNothing);
    await app.finish();
  });
}
