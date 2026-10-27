import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:pack_log/shared/widgets/ds_picker_sheet.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';
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

  testWidgets('le intestazioni dei gruppi stanno sul bordo del gruppo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DsPickerSheet<String>(
            title: 'Titolo',
            items: const ['uno', 'due'],
            getLabel: (s) => s,
            groupOf: (_) => 'Gruppo A',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    // Come in ai_home_group: l'intestazione è allineata al bordo del blocco.
    expect(
      tester.getTopLeft(find.text('Gruppo A')).dx,
      tester.getTopLeft(find.byType(DsSettingsGroup)).dx,
    );
  });

  testWidgets('le righe sono DsSettingsRow, un DsSettingsGroup per gruppo', (
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

    expect(find.byType(DsSettingsGroup), findsNWidgets(2));
    expect(find.byType(DsSettingsRow), findsNWidgets(3));
  });

  testWidgets('la scelta attuale ha la spunta', (tester) async {
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

    Finder check(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byIcon(Icons.check),
    );
    expect(check('picker_item_0'), findsNothing);
    expect(check('picker_item_1'), findsOneWidget);
  });

  testWidgets('getLeading va al posto dell\'icona', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DsPickerSheet<String>(
            title: 'Titolo',
            items: const ['uno'],
            getLabel: (s) => s,
            getIcon: (_) => Icons.home_outlined,
            getLeading: (_) => const Text('X'),
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('X'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets(
    'lista lunga su schermo piccolo: la cornice ha un tetto e si scorre',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [for (var i = 0; i < 60; i++) 'voce $i'];
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await DsPickerSheet.show<String>(
                    context: context,
                    title: 'Titolo',
                    items: items,
                    getLabel: (s) => s,
                  );
                },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('apri'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        tester.getSize(find.byType(DsFormSheet)).height,
        lessThanOrEqualTo(0.9 * 568),
      );

      final lastRow = find.byKey(const ValueKey('picker_item_59'));
      await tester.scrollUntilVisible(
        lastRow,
        200,
        scrollable: find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('sheet_close')), findsOneWidget);

      await tester.tap(lastRow);
      await tester.pumpAndSettle();
      expect(result, 'voce 59');
    },
  );

  testWidgets('ha la testata condivisa con la x', (tester) async {
    var result = 'mai chiamato';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result =
                    await DsPickerSheet.show<String>(
                      context: context,
                      title: 'Titolo',
                      items: const ['uno', 'due'],
                      getLabel: (s) => s,
                    ) ??
                    'null';
              },
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet_close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();
    expect(result, 'null');
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
