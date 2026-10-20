import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  Future<ScreenshotApp> openCalzini(WidgetTester tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    await app.tap(find.text('Calzini'));
    return app;
  }

  String nameText(WidgetTester tester) => tester
      .widget<TextFormField>(find.byKey(const Key('item_sheet_name')))
      .controller!
      .text;

  CategoryPillState pillOf(WidgetTester tester, ItemCategory category) => tester
      .widget<CategoryPill>(
        find.byWidgetPredicate(
          (w) => w is CategoryPill && w.category == category,
        ),
      )
      .pillState;

  /// Apre la scheda di creazione sopra la casa e ne raccoglie il risultato.
  Future<({ScreenshotApp app, Future<ItemModel?> result})> openNew(
    WidgetTester tester, {
    String initialName = '',
  }) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    final context = tester.element(find.byType(Scaffold).last);
    final result = showNewItemSheet(
      context,
      houseId: kHomeId,
      initialName: initialName,
      submitLabel: 'Aggiungi',
    );
    await app.settle();
    return (app: app, result: result);
  }

  testWidgets('mostra nome, categoria, quantità e spazio', (tester) async {
    final app = await openCalzini(tester);
    expect(find.text('Modifica oggetto'), findsOneWidget);
    expect(nameText(tester), 'Calzini');
    expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.forced);
    for (final other in ItemCategory.values.skip(1)) {
      expect(pillOf(tester, other), CategoryPillState.inactive);
    }
    expect(find.text('7'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('item_sheet_space')),
        matching: find.text('Cassettiera'),
      ),
      findsOneWidget,
    );
    await app.finish();
  });

  testWidgets('azioni a destra: chiusura prima del menu', (tester) async {
    final app = await openCalzini(tester);

    expect(
      tester.getCenter(find.byKey(const Key('sheet_close'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('item_sheet_menu'))).dx),
    );
    await app.finish();
  });

  testWidgets('toccare un\'altra categoria la sceglie', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.text('Varie'));
    expect(pillOf(tester, ItemCategory.varie), CategoryPillState.forced);
    expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inactive);

    // Nella modifica una categoria c'è sempre: ritoccarla non la toglie.
    await app.tap(find.text('Varie'));
    expect(pillOf(tester, ItemCategory.varie), CategoryPillState.forced);
    await app.finish();
  });

  testWidgets('Dettagli: il campo nota è sempre visibile e si salva', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    final context = tester.element(find.byKey(const Key('item_sheet_note')));
    final noteBottom = tester
        .getRect(find.byKey(const Key('item_sheet_note')))
        .bottom;
    final saveTop = tester
        .getRect(find.byKey(const Key('item_sheet_save')))
        .top;
    expect(saveTop - noteBottom, greaterThanOrEqualTo(context.spacingLg - 0.1));

    await app.enterText(
      find.byKey(const Key('item_sheet_note')),
      'Quelli di lana',
    );
    await app.tap(find.byKey(const Key('item_sheet_save')));
    await app.tap(find.text('Calzini'));
    final note = tester.widget<TextFormField>(
      find.byKey(const Key('item_sheet_note')),
    );
    expect(note.controller!.text, 'Quelli di lana');
    await app.finish();
  });

  testWidgets('+ e Salva aggiornano la quantità nella lista', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.byIcon(Icons.add_circle_outline));
    await app.tap(find.byKey(const Key('item_sheet_save')));
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    expect(find.text('x8'), findsOneWidget);
    await app.finish();
  });

  testWidgets('senza nome non salva', (tester) async {
    final app = await openCalzini(tester);
    await app.enterText(find.byKey(const Key('item_sheet_name')), '  ');
    await app.tap(find.byKey(const Key('item_sheet_save')));
    expect(find.byKey(const Key('item_sheet_name')), findsOneWidget);
    expect(find.text('common.name_required_validation'.tr()), findsOneWidget);
    await app.finish();
  });

  testWidgets('Elimina dal menu, con conferma, toglie l oggetto', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    await app.tap(find.byKey(const Key('item_sheet_menu')));
    await app.tap(find.text('Elimina').last);
    // Conferma nel dialog.
    await app.tap(find.text('Elimina').last);
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    expect(find.text('Calzini'), findsNothing);
    await app.finish();
  });

  testWidgets('il − e il + della quantità sono neutri', (tester) async {
    final app = await openCalzini(tester);
    final plus = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(plus.color, isNot(AppTheme.light.colorScheme.primary));
    await app.finish();
  });

  testWidgets('oggetto non trovato: la scheda si chiude da sola', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    final context = tester.element(find.byType(Scaffold).last);
    unawaited(showItemSheet(context, houseId: kHomeId, itemId: 'non-esiste'));
    await app.settle();
    expect(find.byType(ItemSheet), findsNothing);
    expect(find.byKey(const Key('sheet_close')), findsNothing);
    await app.finish();
  });

  group('nuovo oggetto', () {
    testWidgets('parte dal nome scritto, senza menu', (tester) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Ciab');
      expect(find.text('Nuovo oggetto'), findsOneWidget);
      expect(nameText(tester), 'Ciab');
      expect(find.byKey(const Key('item_sheet_menu')), findsNothing);
      expect(find.text('Aggiungi'), findsOneWidget);
      await app.finish();
    });

    testWidgets('propone la categoria dal nome e crea con quella', (
      tester,
    ) async {
      final (:app, :result) = await openNew(tester, initialName: 'Maglietta');
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inferred);

      await app.tap(find.byKey(const Key('item_sheet_save')));
      final created = await result;
      expect(created, isNotNull);
      expect(created!.name, 'Maglietta');
      expect(created.category, ItemCategory.vestiti);
      expect(created.houseId, kHomeId);
      expect(find.text('Maglietta'), findsOneWidget);
      await app.finish();
    });

    testWidgets('la categoria toccata vince sulla proposta, ritoccata torna', (
      tester,
    ) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Maglietta');
      await app.tap(find.text('Elettronica'));
      expect(
        pillOf(tester, ItemCategory.elettronica),
        CategoryPillState.forced,
      );
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inactive);

      await app.tap(find.text('Elettronica'));
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inferred);
      await app.finish();
    });

    testWidgets('senza nome non crea', (tester) async {
      final (:app, result: _) = await openNew(tester);
      await app.tap(find.byKey(const Key('item_sheet_save')));
      expect(find.byKey(const Key('item_sheet_name')), findsOneWidget);
      expect(find.text('common.name_required_validation'.tr()), findsOneWidget);
      await app.finish();
    });
  });
}
