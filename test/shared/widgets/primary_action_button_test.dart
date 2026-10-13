import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/primary_action_button.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          colorSchemeSeed: Colors.orange,
        ),
        home: Scaffold(body: Center(child: child)),
      );

  PrimaryActionButton button({
    bool enabled = true,
    PrimaryActionStyle style = PrimaryActionStyle.outlined,
    String label = 'Oggetto',
    VoidCallback? onPressed,
  }) => PrimaryActionButton(
    icon: Icons.add,
    label: label,
    semanticLabel: 'Aggiungi oggetti',
    enabled: enabled,
    style: style,
    onPressed: onPressed ?? () {},
  );

  Material materialOf(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(
          of: find.byType(PrimaryActionButton),
          matching: find.byType(Material),
        )
        .first,
  );

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(PrimaryActionButton))).colorScheme;

  testWidgets('icona ed etichetta breve sempre visibili', (tester) async {
    await tester.pumpWidget(wrap(button()));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Oggetto'), findsOneWidget);
  });

  testWidgets('colori dei tre stili attivi', (tester) async {
    for (final style in PrimaryActionStyle.values) {
      await tester.pumpWidget(wrap(button(style: style)));
      final scheme = schemeOf(tester);
      final expected = switch (style) {
        PrimaryActionStyle.filled => scheme.primary,
        PrimaryActionStyle.tonal => scheme.primaryContainer,
        PrimaryActionStyle.outlined => scheme.surfaceContainer,
      };
      expect(materialOf(tester).color, expected, reason: style.name);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('spento (${brightness.name}): valori di disabilitato M3, '
        'ma risponde al tocco', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          button(enabled: false, onPressed: () => taps++),
          brightness: brightness,
        ),
      );
      final scheme = schemeOf(tester);
      expect(
        materialOf(tester).color,
        scheme.onSurface.withValues(alpha: 0.12),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.color, scheme.onSurface.withValues(alpha: 0.38));

      await tester.tap(find.byType(PrimaryActionButton));
      expect(taps, 1);
    });
  }

  testWidgets('caratteri grandi: etichetta su una riga, nessun overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Center(
              child: button(label: 'Un\'etichetta davvero molto lunga'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.text('Un\'etichetta davvero molto lunga'),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('semantica: frase completa, letta una volta sola', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(button()));
    expect(find.bySemanticsLabel('Aggiungi oggetti'), findsOneWidget);
    expect(find.bySemanticsLabel('Oggetto'), findsNothing);
    handle.dispose();
  });
}
