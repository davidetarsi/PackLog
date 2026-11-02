import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
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

  Future<ScreenshotApp> openNewKit(WidgetTester tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/new');
    return app;
  }

  Finder nameField() => find.byKey(const Key('kit_name_field'));
  Finder rapidFire() => find.byType(TextField).last;
  Finder pill(String label) => find.widgetWithText(DsChoicePill, label);
  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<DsChoicePill>(pill(label)).selected;

  Future<List<KitModel>> kitsOf(ScreenshotApp app) async =>
      (await app.tester.runAsync(
        () =>
            app.container.read(kitRepositoryProvider).watchKits(kHomeId).first,
      ))!;

  Future<void> submitRapidFire(ScreenshotApp app, String text) async {
    await app.enterText(rapidFire(), text);
    await app.tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();
  }

  /// Tocca un widget che può stare sotto il bordo dello schermo.
  Future<void> tapScrolled(ScreenshotApp app, Finder finder) async {
    await app.tester.ensureVisible(finder.first);
    await app.tap(finder);
  }

  Future<void> save(ScreenshotApp app) => app.tap(find.text('Salva'));

  testWidgets('scrivere "Sci" preseleziona ski e mostra la frase', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    await app.enterText(nameField(), 'Sci');

    expect(isSelected(tester, 'Sci e neve'), isTrue);
    expect(
      find.text(
        '«Sci e neve» l\'ho scelto io dal nome: toccalo per toglierlo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Lo aggiungo da solo ai viaggi con…'), findsOneWidget);
    expect(find.text('(facoltativo)'), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'toccare la pillola preselezionata la toglie e la frase sparisce',
    (tester) async {
      final app = await openNewKit(tester);
      await app.enterText(nameField(), 'Sci');
      await app.tap(pill('Sci e neve'));

      expect(isSelected(tester, 'Sci e neve'), isFalse);
      expect(find.textContaining('l\'ho scelto io dal nome'), findsNothing);

      // Riscrivere il nome non la rimette: l'utente l'ha tolta.
      await app.enterText(nameField(), 'Sci di fondo');
      expect(isSelected(tester, 'Sci e neve'), isFalse);
      await app.finish();
    },
  );

  testWidgets('un mezzo si riconosce dal nome: "Aereo" preseleziona il mezzo', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    await app.enterText(nameField(), 'Kit aereo');

    expect(isSelected(tester, 'Aereo'), isTrue);
    await save(app);

    final kit = (await kitsOf(app)).single;
    expect(kit.name, 'Kit aereo');
    expect(kit.transports, ['plane']);
    await app.finish();
  });

  testWidgets(
    'invio nel Rapid Fire crea l\'oggetto nella casa e lo mette nel kit con le copie',
    (tester) async {
      final app = await openNewKit(tester);
      await app.enterText(nameField(), 'Montagna');
      await submitRapidFire(app, '2 Zaino da trekking');

      expect(find.text('Nel kit · 1'), findsOneWidget);
      expect(find.text('Zaino da trekking'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await save(app);
      final kit = (await kitsOf(app)).single;
      expect(kit.items.single.copies, 2);
      final houseItems = (await app.tester.runAsync(
        () => app.container
            .read(itemRepositoryProvider)
            .getItemsByHouseId(kHomeId),
      ))!;
      final created = houseItems.singleWhere(
        (i) => i.name == 'Zaino da trekking',
      );
      expect(kit.items.single.itemId, created.id);
      await app.finish();
    },
  );

  testWidgets('toccare un oggetto in Già in casa lo aggiunge senza crearlo', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    final before = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    await app.enterText(nameField(), 'Mare');
    await app.enterText(rapidFire(), 'Calz');

    expect(find.textContaining('Già in casa'), findsOneWidget);
    await tapScrolled(app, find.byKey(const Key('kit_match_item-4')));

    expect(find.text('Nel kit · 1'), findsOneWidget);
    await save(app);
    final kit = (await kitsOf(app)).single;
    expect(kit.items.map((i) => i.itemId), ['item-4']);
    final after = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    expect(after.length, before.length);
    await app.finish();
  });

  testWidgets('X toglie l\'oggetto dal kit, non dalla casa', (tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final repo = app.container.read(kitRepositoryProvider);
    final kit = (await app.tester.runAsync(() async {
      final k = await repo.createKit(houseId: kHomeId, name: 'Sci');
      await repo.addItems(k.id, {'item-0': 1, 'item-1': 2});
      return k;
    }))!;
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}/edit');
    expect(find.text('Nel kit · 2'), findsOneWidget);

    await tapScrolled(app, find.byKey(const Key('kit_item_remove_item-0')));
    expect(find.text('Nel kit · 1'), findsOneWidget);
    await save(app);

    final saved = (await kitsOf(app)).single;
    expect(saved.items.map((i) => i.itemId), ['item-1']);
    final houseItems = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    expect(houseItems.any((i) => i.id == 'item-0'), isTrue);
    await app.finish();
  });

  testWidgets('lo stepper cambia le copie e il salvataggio le tiene', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final repo = app.container.read(kitRepositoryProvider);
    final kit = (await app.tester.runAsync(() async {
      final k = await repo.createKit(houseId: kHomeId, name: 'Sci');
      await repo.addItems(k.id, {'item-0': 2});
      return k;
    }))!;
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}/edit');

    Finder inRow(IconData icon) => find.descendant(
      of: find.byKey(const Key('kit_item_row_item-0')),
      matching: find.byIcon(icon),
    );
    await tapScrolled(app, inRow(Icons.add_circle_outline));
    await tapScrolled(app, inRow(Icons.add_circle_outline));
    await tapScrolled(app, inRow(Icons.remove_circle_outline));
    await save(app);

    expect((await kitsOf(app)).single.items.single.copies, 3);
    await app.finish();
  });

  testWidgets('modificare il nome e le pillole salva sul kit esistente', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final repo = app.container.read(kitRepositoryProvider);
    final kit = (await app.tester.runAsync(
      () => repo.createKit(houseId: kHomeId, name: 'Sci'),
    ))!;
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}/edit');

    // In modifica il nome non cambia le pillole da solo.
    await app.enterText(nameField(), 'Sci e snowboard');
    await app.tap(find.byKey(const Key('kit_uses_more')));
    expect(isSelected(tester, 'Sci e neve'), isFalse);
    await tapScrolled(app, pill('Sci e neve'));
    await save(app);

    final saved = (await kitsOf(app)).single;
    expect(saved.id, kit.id);
    expect(saved.name, 'Sci e snowboard');
    expect(saved.activities, ['ski']);
    await app.finish();
  });
}
