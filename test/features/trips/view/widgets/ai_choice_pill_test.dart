import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_choice_pill.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_parts.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

/// Il riquadro visibile della pillola (32 dp), non l'area di tocco.
Finder _face(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byKey(const ValueKey('ai_choice_pill_face')),
);

/// Il BoxDecoration del riquadro visibile.
BoxDecoration _decorationOf(WidgetTester tester, String label) {
  final container = tester.widget<Container>(_face(label));
  return container.decoration! as BoxDecoration;
}

void main() {
  group('AiChoicePill', () {
    testWidgets('il riquadro visibile è alto 32 dp', (tester) async {
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: false, onTap: () {}),
      );

      expect(tester.getSize(_face('Mare')).height, 32);
    });

    testWidgets('l area toccabile è alta almeno 48 dp', (tester) async {
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: false, onTap: () {}),
      );

      final tappable = find.ancestor(
        of: find.text('Mare'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tappable).height, greaterThanOrEqualTo(48));
    });

    testWidgets('non mostra mai la spunta', (tester) async {
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: true, onTap: () {}),
      );

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('se scelta: bordo e testo onSurface, sfondo trasparente', (
      tester,
    ) async {
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: true, onTap: () {}),
      );
      final cs = AppTheme.light.colorScheme;

      final decoration = _decorationOf(tester, 'Mare');
      final border = decoration.border! as Border;
      expect(border.top.color, cs.onSurface);
      expect(decoration.color, isNull);

      final text = tester.widget<Text>(find.text('Mare'));
      expect(text.style?.color, cs.onSurface);
    });

    testWidgets(
      'se non scelta: bordo outlineVariant e testo onSurfaceVariant',
      (tester) async {
        await _pump(
          tester,
          AiChoicePill(label: 'Mare', selected: false, onTap: () {}),
        );
        final cs = AppTheme.light.colorScheme;

        final border = _decorationOf(tester, 'Mare').border! as Border;
        expect(border.top.color, cs.outlineVariant);

        final text = tester.widget<Text>(find.text('Mare'));
        expect(text.style?.color, cs.onSurfaceVariant);
      },
    );

    testWidgets('due pillole in un Wrap stanno sulla stessa riga', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: Wrap(
                children: [
                  AiChoicePill(label: 'Mare', selected: false, onTap: () {}),
                  AiChoicePill(label: 'Montagna', selected: true, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      final first = tester.getTopLeft(find.text('Mare')).dy;
      final second = tester.getTopLeft(find.text('Montagna')).dy;
      expect(second, first);
    });

    testWidgets('l area toccabile è larga quanto il riquadro, non la riga', (
      tester,
    ) async {
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: false, onTap: () {}),
      );

      final tappable = find.ancestor(
        of: find.text('Mare'),
        matching: find.byType(InkWell),
      );
      final tapWidth = tester.getSize(tappable).width;
      final faceWidth = tester.getSize(_face('Mare')).width;
      expect(tapWidth, lessThan(200));
      expect(tapWidth, closeTo(faceWidth, 1));
    });

    testWidgets('espone un pulsante con lo stato di scelta', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: true, onTap: () {}),
      );

      final node = tester.getSemantics(find.text('Mare'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('il tocco chiama onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AiChoicePill(label: 'Mare', selected: false, onTap: () => taps++),
      );

      await tester.tap(find.text('Mare'));
      expect(taps, 1);
    });
  });

  group('PackPill senza spunta', () {
    testWidgets('scelta non mostra Icons.check ma la sua icona', (
      tester,
    ) async {
      await _pump(
        tester,
        const PackPill(
          label: 'Bagaglio',
          icon: Icons.luggage_outlined,
          selected: true,
        ),
      );

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.luggage_outlined), findsOneWidget);
    });

    testWidgets('scelta: sfondo trasparente e bordo onSurface', (tester) async {
      await _pump(
        tester,
        const PackPill(
          label: 'Bagaglio',
          icon: Icons.luggage_outlined,
          selected: true,
        ),
      );
      final cs = AppTheme.light.colorScheme;

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Bagaglio'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.transparent);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, cs.onSurface);
    });
  });
}
