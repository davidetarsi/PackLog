import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/ds_badge.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('DsQuantityBadge', () {
    testWidgets('non mostra nulla per una quantità singola senza massimo', (
      tester,
    ) async {
      // "x1" è il caso implicito: ripetuto su ogni riga è la voce più
      // frequente della schermata e non informa.
      await _pump(tester, const DsQuantityBadge(current: 1));

      expect(find.textContaining('x'), findsNothing);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('mostra il badge quando la quantità è maggiore di uno', (
      tester,
    ) async {
      await _pump(tester, const DsQuantityBadge(current: 7));

      expect(find.text('x7'), findsOneWidget);
    });

    testWidgets('mostra il badge a quantità 1 se esiste un massimo', (
      tester,
    ) async {
      // Qui "x1/5" dice quanto è stato preso su quanto è disponibile: è
      // informazione, non rumore.
      await _pump(tester, const DsQuantityBadge(current: 1, max: 5));

      expect(find.text('x1/5'), findsOneWidget);
    });

    testWidgets('non mostra la frazione quando current copre il massimo', (
      tester,
    ) async {
      await _pump(tester, const DsQuantityBadge(current: 5, max: 5));

      expect(find.text('x5'), findsOneWidget);
    });

    testWidgets('mostra zero, che non è il caso implicito', (tester) async {
      await _pump(tester, const DsQuantityBadge(current: 0));

      expect(find.text('x0'), findsOneWidget);
    });
  });
}
