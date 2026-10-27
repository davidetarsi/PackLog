import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/ds_divider.dart';
import 'package:pack_log/shared/widgets/ds_steps.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('DsSteps', () {
    testWidgets('il passo completato mostra la spunta al posto del numero', (
      tester,
    ) async {
      await _pump(
        tester,
        const DsSteps(labels: ['Viaggio', 'Valigia'], current: 1),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('il passo corrente mostra il proprio numero', (tester) async {
      await _pump(
        tester,
        const DsSteps(labels: ['Viaggio', 'Valigia'], current: 1),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('con current a zero non ci sono spunte', (tester) async {
      await _pump(
        tester,
        const DsSteps(labels: ['Viaggio', 'Valigia'], current: 0),
      );

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('l\'etichetta del passo corrente è in grassetto', (
      tester,
    ) async {
      await _pump(
        tester,
        const DsSteps(labels: ['Viaggio', 'Valigia'], current: 1),
      );

      final current = tester.widget<Text>(find.text('Valigia'));
      final other = tester.widget<Text>(find.text('Viaggio'));

      expect(current.style?.fontWeight, FontWeight.w600);
      expect(other.style?.fontWeight, isNot(FontWeight.w600));
    });

    testWidgets('mostra tutte le etichette e un divisore tra i passi', (
      tester,
    ) async {
      await _pump(
        tester,
        const DsSteps(labels: ['Viaggio', 'Valigia', 'Riepilogo'], current: 0),
      );

      expect(find.text('Viaggio'), findsOneWidget);
      expect(find.text('Valigia'), findsOneWidget);
      expect(find.text('Riepilogo'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('il divisore tra i passi è centrato sul cerchio', (
      tester,
    ) async {
      await _pump(
        tester,
        const DsSteps(labels: ['Viaggio', 'Valigia'], current: 0),
      );

      final line = tester.getCenter(find.byType(DsDivider).first).dy;
      final circle = tester.getCenter(find.text('1')).dy;
      expect(line, closeTo(circle, 0.5));
    });
  });
}
