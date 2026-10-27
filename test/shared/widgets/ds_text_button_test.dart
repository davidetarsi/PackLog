import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_text_button.dart';

/// [DsTextButton] è il bottone di solo testo: testo, icona e colore decisi
/// qui, non nel chiamante.
void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    VoidCallback? onPressed,
    IconData? icon,
    bool iconAtEnd = false,
    bool destructive = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: DsTextButton(
              label: 'Etichetta',
              onPressed: onPressed,
              icon: icon,
              iconAtEnd: iconAtEnd,
              destructive: destructive,
            ),
          ),
        ),
      ),
    );
  }

  Text labelText(WidgetTester tester) =>
      tester.widget<Text>(find.text('Etichetta'));

  /// Ordine di testo e icona dentro la riga del bottone, ignorando gli spazi.
  List<Type> contentOrder(WidgetTester tester) {
    final row = tester.widget<Row>(
      find
          .descendant(of: find.byType(DsTextButton), matching: find.byType(Row))
          .first,
    );
    // Il testo sta dentro un Flexible: si scarta per leggere il contenuto.
    final content = row.children.map((c) => c is Flexible ? c.child : c);
    return content
        .where((c) => c is Text || c is Icon)
        .map((c) => c.runtimeType)
        .toList();
  }

  ColorScheme colorsOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(DsTextButton))).colorScheme;

  testWidgets('tocco chiama onPressed', (tester) async {
    var taps = 0;
    await pumpButton(tester, onPressed: () => taps++);

    await tester.tap(find.byType(DsTextButton));

    expect(taps, 1);
  });

  testWidgets('spento: non risponde e il testo è al 50%', (tester) async {
    await pumpButton(tester, onPressed: null);

    await tester.tap(find.byType(DsTextButton), warnIfMissed: false);

    final expected = colorsOf(
      tester,
    ).onSurface.withValues(alpha: AppOpacity.disabled);
    expect(labelText(tester).style?.color, expected);
  });

  testWidgets('distruttivo: testo rosso', (tester) async {
    await pumpButton(tester, onPressed: () {}, destructive: true);

    expect(labelText(tester).style?.color, colorsOf(tester).error);
  });

  testWidgets('area di tocco almeno 48', (tester) async {
    await pumpButton(tester, onPressed: () {});

    final size = tester.getSize(find.byType(DsTextButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('icona in fondo con iconAtEnd', (tester) async {
    await pumpButton(
      tester,
      onPressed: () {},
      icon: Icons.arrow_forward,
      iconAtEnd: true,
    );

    expect(contentOrder(tester), [Text, Icon]);
  });

  testWidgets('icona prima del testo senza iconAtEnd', (tester) async {
    await pumpButton(tester, onPressed: () {}, icon: Icons.add);

    expect(contentOrder(tester), [Icon, Text]);
  });
}
