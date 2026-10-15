import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_bottom_sheet_handle.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';
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

  testWidgets('mostra nome, categoria, quantità e spazio', (tester) async {
    final app = await openCalzini(tester);
    expect(nameText(tester), 'Calzini');
    expect(
      find.descendant(
        of: find.byKey(const Key('item_sheet_category')),
        matching: find.text('Vestiti'),
      ),
      findsOneWidget,
    );
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

  testWidgets('senza maniglia, menu a sinistra e chiusura a destra', (
    tester,
  ) async {
    final app = await openCalzini(tester);

    expect(find.byType(DsBottomSheetHandle), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('item_sheet_menu'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('item_sheet_close'))).dx),
    );
    await app.finish();
  });

  testWidgets('separa card, nota e CTA con spaziatura di sezione', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    final context = tester.element(
      find.byKey(const Key('item_sheet_add_note')),
    );
    final settingsBottom = tester.getRect(find.byType(DsSettingsGroup)).bottom;
    final addNoteRect = tester.getRect(
      find.byKey(const Key('item_sheet_add_note')),
    );
    final saveTop = tester
        .getRect(find.byKey(const Key('item_sheet_save')))
        .top;

    expect(
      addNoteRect.top - settingsBottom,
      greaterThanOrEqualTo(context.spacingMd - 0.1),
    );
    expect(
      saveTop - addNoteRect.bottom,
      greaterThanOrEqualTo(context.spacingMd - 0.1),
    );
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

  testWidgets('Aggiungi una nota apre il campo', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.byKey(const Key('item_sheet_add_note')));
    expect(find.byKey(const Key('item_sheet_note')), findsOneWidget);
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

  testWidgets('solo Salva è arancio: il − e il + sono neutri', (tester) async {
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
    expect(find.byKey(const Key('item_sheet_close')), findsNothing);
    await app.finish();
  });
}
