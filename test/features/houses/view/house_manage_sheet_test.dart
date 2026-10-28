import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/view/house_manage_sheet.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

Future<void> _open(
  WidgetTester tester, {
  required VoidCallback onDelete,
  VoidCallback? onSelectItems,
  VoidCallback? onSetPrimary,
  bool isPrimary = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHouseManageSheet(
              context,
              houseId: 'h1',
              isPrimary: isPrimary,
              houseName: 'Casa',
              onSetPrimary: onSetPrimary ?? () {},
              onDelete: onDelete,
              onSelectItems: onSelectItems,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ha la testata del design system', (tester) async {
    await _open(tester, onDelete: () {});

    expect(find.byType(DsSheetHeader), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('Elimina chiude il sheet e chiama onDelete', (tester) async {
    var deleted = false;
    await _open(tester, onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.byType(DsSheetHeader), findsNothing);
  });

  testWidgets('Seleziona oggetti chiude il sheet e chiama onSelectItems', (
    tester,
  ) async {
    var called = false;
    await _open(tester, onDelete: () {}, onSelectItems: () => called = true);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(find.byType(DsSheetHeader), findsNothing);
  });

  testWidgets('su schermo basso le azioni restano raggiungibili scorrendo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var deleted = false;
    await _open(tester, onDelete: () => deleted = true, onSelectItems: () {});

    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usa la cornice dei fogli con trascinamento attivo', (
    tester,
  ) async {
    await _open(tester, onDelete: () {});

    expect(find.byType(DsFormSheet), findsOneWidget);
  });

  testWidgets('Elimina è una riga di errore separata', (tester) async {
    await _open(tester, onDelete: () {}, onSelectItems: () {});

    final deleteRow = tester.widget<DsSettingsRow>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(DsSettingsRow),
      ),
    );
    expect(deleteRow.destructive, isTrue);

    final deleteGroup = tester.widget<DsSettingsGroup>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(DsSettingsGroup),
      ),
    );
    expect(deleteGroup.children, hasLength(1));
    expect(find.byType(DsSettingsGroup), findsNWidgets(2));
  });

  testWidgets('casa già principale: la riga è spenta', (tester) async {
    var called = false;
    await _open(
      tester,
      onDelete: () {},
      isPrimary: true,
      onSetPrimary: () => called = true,
    );

    final row = tester.widget<DsSettingsRow>(
      find.ancestor(
        of: find.byIcon(Icons.push_pin_outlined),
        matching: find.byType(DsSettingsRow),
      ),
    );
    expect(row.enabled, isFalse);

    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('la x chiude senza azioni', (tester) async {
    var deleted = false;
    var selected = false;
    await _open(
      tester,
      onDelete: () => deleted = true,
      onSelectItems: () => selected = true,
    );

    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();

    expect(find.byType(DsSheetHeader), findsNothing);
    expect(deleted, isFalse);
    expect(selected, isFalse);
  });
}
