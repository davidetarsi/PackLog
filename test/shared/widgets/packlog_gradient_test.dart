import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_motion.dart';
import 'package:pack_log/shared/widgets/packlog_gradient.dart';

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: Center(child: child)),
  ),
);

const _period = Duration(seconds: 6);

void main() {
  test('i tre colori sono arancio, ambra e rosa', () {
    expect(kPackLogGradientColors, const [
      Color(0xFFFF8A50),
      Color(0xFFFBBF24),
      Color(0xFFF472B6),
    ]);
  });

  group('PackLogGradientBorder', () {
    testWidgets('loops 2: si muove e dopo 2 x period non ha più ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const PackLogGradientBorder(
            radius: 16,
            loops: 2,
            child: SizedBox(width: 100, height: 60),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pump(_period);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pump(_period);
      // Finiti i giri il bordo sfuma piano verso l'opacità di riposo...
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      // ...e finita la dissolvenza non resta nessun ticker.
      await tester.pump(AppMotion.slow);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, 0);
      // Dopo i giri il bordo resta lì, colorato e fermo.
      expect(find.byType(PackLogGradientBorder), findsOneWidget);
    });

    testWidgets('loops 0: fermo, nessun ticker', (tester) async {
      await tester.pumpWidget(
        _app(
          const PackLogGradientBorder(
            radius: 16,
            child: SizedBox(width: 100, height: 60),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('loops -1: gira finché è montato', (tester) async {
      await tester.pumpWidget(
        _app(
          const PackLogGradientBorder(
            radius: 16,
            loops: -1,
            child: SizedBox(width: 100, height: 60),
          ),
        ),
      );
      await tester.pump(_period * 5);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(_app(const SizedBox()));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('con disableAnimations nessun ticker', (tester) async {
      await tester.pumpWidget(
        _app(
          const PackLogGradientBorder(
            radius: 16,
            loops: -1,
            child: SizedBox(width: 100, height: 60),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('mostra il figlio', (tester) async {
      await tester.pumpWidget(
        _app(const PackLogGradientBorder(radius: 16, child: Text('dentro'))),
      );
      expect(find.text('dentro'), findsOneWidget);
    });
  });

  group('PackLogSparkle', () {
    testWidgets('breathing: respira finché è montata', (tester) async {
      await tester.pumpWidget(
        _app(const PackLogSparkle(size: 16, breathing: true)),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('senza breathing è ferma', (tester) async {
      await tester.pumpWidget(_app(const PackLogSparkle(size: 16)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('con disableAnimations è ferma anche se breathing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const PackLogSparkle(size: 16, breathing: true),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('ha la dimensione richiesta', (tester) async {
      await tester.pumpWidget(_app(const PackLogSparkle(size: 20)));
      expect(tester.getSize(find.byType(PackLogSparkle)), const Size(20, 20));
    });
  });
}
