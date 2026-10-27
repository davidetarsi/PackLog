import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_checkbox.dart';

/// [DsCheckbox] e [DsSwitch]: il tocco inverte il valore, il tocco minimo è
/// di 48 e senza `onChanged` il controllo è spento.
void main() {
  Future<void> pumpIn(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('DsCheckbox', () {
    testWidgets('tocco inverte il valore', (tester) async {
      bool? received;
      await pumpIn(
        tester,
        DsCheckbox(value: false, onChanged: (v) => received = v),
      );

      await tester.tap(find.byType(DsCheckbox));
      await tester.pump();

      expect(received, isTrue);
    });

    testWidgets('spenta senza onChanged', (tester) async {
      await pumpIn(tester, const DsCheckbox(value: false, onChanged: null));

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      await tester.tap(find.byType(DsCheckbox));
      expect(tester.takeException(), isNull);
    });

    testWidgets('area di tocco 48', (tester) async {
      await pumpIn(tester, DsCheckbox(value: false, onChanged: (_) {}));

      final size = tester.getSize(find.byType(Checkbox));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('semanticLabel arriva alla semantica', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIn(
        tester,
        DsCheckbox(value: true, onChanged: (_) {}, semanticLabel: 'Ricorda'),
      );

      expect(find.bySemanticsLabel('Ricorda'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DsSwitch', () {
    testWidgets('tocco inverte il valore', (tester) async {
      bool? received;
      await pumpIn(
        tester,
        DsSwitch(value: false, onChanged: (v) => received = v),
      );

      await tester.tap(find.byType(DsSwitch));
      await tester.pump();

      expect(received, isTrue);
    });

    testWidgets('spento senza onChanged', (tester) async {
      await pumpIn(tester, const DsSwitch(value: false, onChanged: null));

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      await tester.tap(find.byType(DsSwitch));
      expect(tester.takeException(), isNull);
    });

    testWidgets('area di tocco 48', (tester) async {
      await pumpIn(tester, DsSwitch(value: false, onChanged: (_) {}));

      final size = tester.getSize(find.byType(Switch));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
