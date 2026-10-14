import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/view/house_manage_sheet.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

Future<void> _open(
  WidgetTester tester, {
  required VoidCallback onDelete,
  VoidCallback? onSelectItems,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHouseManageSheet(
              context,
              houseId: 'h1',
              isPrimary: false,
              houseName: 'Casa',
              onSetPrimary: () {},
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
}
