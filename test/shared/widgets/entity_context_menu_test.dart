import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';
import 'package:pack_log/shared/widgets/entity_context_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Il menu della pressione lunga è un foglio con le voci di [DsSettingsRow].
/// Ogni scelta chiude il foglio e restituisce la sua azione; la x e il tasto
/// indietro restituiscono null.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late List<EntityContextMenuAction?> results;

  Future<void> pumpApp(
    WidgetTester tester, {
    bool showSaveAction = false,
    bool isSaved = false,
    bool showSetPrimaryAction = false,
    bool isPrimary = false,
  }) async {
    results = [];
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () async {
                  results.add(
                    await showEntityContextMenu(
                      context: context,
                      entityType: 'Casa',
                      title: 'Casa al mare',
                      showSaveAction: showSaveAction,
                      isSaved: isSaved,
                      showSetPrimaryAction: showSetPrimaryAction,
                      isPrimary: isPrimary,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('si apre come foglio con titolo e voci', (tester) async {
    await pumpApp(tester, showSaveAction: true, showSetPrimaryAction: true);
    await openMenu(tester);

    expect(find.byType(DsFormSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(
      tester.widget<DsSheetHeader>(find.byType(DsSheetHeader)).title,
      'Casa al mare',
    );
    expect(
      find.text('dialogs.context_menu_copy'.tr(args: ['Casa'])),
      findsOneWidget,
    );
    expect(
      find.text('dialogs.context_menu_save'.tr(args: ['Casa'])),
      findsOneWidget,
    );
    expect(find.text('dialogs.context_menu_set_primary'.tr()), findsOneWidget);
    expect(
      find.text('dialogs.context_menu_delete'.tr(args: ['Casa'])),
      findsOneWidget,
    );
    // Due gruppi: le azioni, poi Elimina da solo.
    expect(find.byType(DsSettingsGroup), findsNWidgets(2));
    expect(find.byType(DsSettingsRow), findsNWidgets(4));
  });

  testWidgets('Elimina restituisce delete', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);

    await tester.tap(
      find.text('dialogs.context_menu_delete'.tr(args: ['Casa'])),
    );
    await tester.pumpAndSettle();

    expect(results, [EntityContextMenuAction.delete]);
    expect(find.byType(DsFormSheet), findsNothing);
  });

  testWidgets('una voce restituisce la sua azione', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);

    await tester.tap(find.text('dialogs.context_menu_copy'.tr(args: ['Casa'])));
    await tester.pumpAndSettle();

    expect(results, [EntityContextMenuAction.copy]);
  });

  testWidgets('la x restituisce null', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);

    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.byType(DsFormSheet), findsNothing);
  });

  testWidgets('il tasto indietro restituisce null', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.byType(DsFormSheet), findsNothing);
  });

  testWidgets('casa principale: la voce è spenta, il tocco non fa nulla', (
    tester,
  ) async {
    await pumpApp(tester, showSetPrimaryAction: true, isPrimary: true);
    await openMenu(tester);

    final label = 'dialogs.context_menu_set_primary'.tr();
    final row = tester.widget<DsSettingsRow>(
      find.ancestor(of: find.text(label), matching: find.byType(DsSettingsRow)),
    );
    expect(row.enabled, isFalse);

    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.byType(DsFormSheet), findsOneWidget);
  });

  testWidgets('casa non principale: la voce è accesa', (tester) async {
    await pumpApp(tester, showSetPrimaryAction: true);
    await openMenu(tester);

    final label = 'dialogs.context_menu_set_primary'.tr();
    final row = tester.widget<DsSettingsRow>(
      find.ancestor(of: find.text(label), matching: find.byType(DsSettingsRow)),
    );
    expect(row.enabled, isTrue);
  });
}
