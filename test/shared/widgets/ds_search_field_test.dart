import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_search_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  InputDecoration decorationOf(WidgetTester tester) =>
      tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

  testWidgets('la x compare solo con del testo', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pump(
      tester,
      DsSearchField(controller: controller, hintText: 'Cerca'),
    );

    expect(find.byKey(const Key('ds_search_clear')), findsNothing);

    await tester.enterText(find.byType(TextField), 'roma');
    await tester.pump();

    expect(find.byKey(const Key('ds_search_clear')), findsOneWidget);
  });

  testWidgets('la x svuota, avvisa e tiene il focus', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final changes = <String>[];
    await pump(
      tester,
      DsSearchField(
        controller: controller,
        focusNode: focusNode,
        hintText: 'Cerca',
        onChanged: changes.add,
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'roma');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ds_search_clear')));
    await tester.pump();

    expect(controller.text, '');
    expect(changes.last, '');
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('in caricamento: rotella al posto della x', (tester) async {
    final controller = TextEditingController(text: 'roma');
    addTearDown(controller.dispose);
    await pump(
      tester,
      DsSearchField(controller: controller, hintText: 'Cerca', isLoading: true),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('ds_search_clear')), findsNothing);
  });

  testWidgets('la rotella è del colore della x, non arancio', (tester) async {
    final controller = TextEditingController(text: 'rom');
    addTearDown(controller.dispose);
    await pump(
      tester,
      DsSearchField(controller: controller, hintText: 'Cerca', isLoading: true),
    );
    final scheme = Theme.of(
      tester.element(find.byType(DsSearchField)),
    ).colorScheme;
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, scheme.onSurfaceVariant);
  });

  testWidgets('lente a sinistra, tranne nella barra', (tester) async {
    await pump(tester, const DsSearchField(hintText: 'Cerca'));
    expect(find.byIcon(Icons.search), findsOneWidget);

    await pump(tester, const DsSearchField(hintText: 'Cerca', inBar: true));
    expect(find.byIcon(Icons.search), findsNothing);
  });

  testWidgets("nella barra non c'è bordo", (tester) async {
    await pump(tester, const DsSearchField(hintText: 'Cerca', inBar: true));

    final decoration = decorationOf(tester);
    expect(decoration.enabledBorder, InputBorder.none);
    expect(decoration.focusedBorder, InputBorder.none);
    expect(decoration.filled, isFalse);
  });

  testWidgets('errore: bordo e testo', (tester) async {
    await pump(
      tester,
      const DsSearchField(
        hintText: 'Luogo',
        errorText: 'Scegli un luogo dalla lista',
      ),
    );

    expect(find.text('Scegli un luogo dalla lista'), findsOneWidget);
  });

  testWidgets('solo hasError: bordo di errore senza testo', (tester) async {
    await pump(tester, const DsSearchField(hintText: 'Luogo', hasError: true));

    final border = decorationOf(tester).enabledBorder as OutlineInputBorder;
    expect(border.borderSide.color, AppTheme.light.colorScheme.error);
  });

  testWidgets('tasto della tastiera: cerca', (tester) async {
    await pump(tester, const DsSearchField(hintText: 'Cerca'));

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.textInputAction, TextInputAction.search);
  });

  testWidgets('cambio di controller: la x segue quello nuovo', (tester) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    first.text = 'milano';
    await pump(tester, DsSearchField(controller: first, hintText: 'Cerca'));
    expect(find.byKey(const Key('ds_search_clear')), findsOneWidget);

    await pump(tester, DsSearchField(controller: second, hintText: 'Cerca'));
    expect(find.byKey(const Key('ds_search_clear')), findsNothing);

    first.text = 'roma';
    await tester.pump();
    expect(find.byKey(const Key('ds_search_clear')), findsNothing);

    second.text = 'roma';
    await tester.pump();
    expect(find.byKey(const Key('ds_search_clear')), findsOneWidget);
  });
}
