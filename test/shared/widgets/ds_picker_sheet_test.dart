import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:pack_log/shared/widgets/ds_picker_sheet.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

Future<String?> _open(WidgetTester tester, {String? selected}) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await DsPickerSheet.show<String>(
                context: context,
                title: 'Titolo',
                items: const ['uno', 'due'],
                getLabel: (s) => s,
                selected: selected,
              );
            },
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('uno'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('ha la testata condivisa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DsPickerSheet<String>(
            title: 'Titolo',
            items: const ['uno', 'due'],
            getLabel: (s) => s,
            selected: 'due',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DsSheetHeader), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('con groupOf intitola ogni gruppo di elementi consecutivi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DsPickerSheet<String>(
            title: 'Titolo',
            items: const ['uno', 'due', 'tre'],
            getLabel: (s) => s,
            groupOf: (s) => s == 'tre' ? 'Gruppo B' : 'Gruppo A',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final headers = tester
        .widgetList<DsGroupHeader>(find.byType(DsGroupHeader))
        .map((h) => h.label);
    expect(headers, ['Gruppo A', 'Gruppo B']);
    expect(find.text('uno'), findsOneWidget);
    expect(find.text('tre'), findsOneWidget);
  });

  testWidgets('senza groupOf non mostra intestazioni', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DsPickerSheet<String>(
            title: 'Titolo',
            items: const ['uno', 'due'],
            getLabel: (s) => s,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DsGroupHeader), findsNothing);
  });

  testWidgets('restituisce l\'elemento toccato', (tester) async {
    expect(await _open(tester, selected: 'due'), 'uno');
  });
}
