import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/app_pill_tab.dart';

void main() {
  testWidgets(
    'AppPill chiama onTap e segna la selezione col bordo d\'accento',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                AppPill(
                  key: const Key('a'),
                  label: 'A',
                  isSelected: true,
                  onTap: () {},
                ),
                AppPill(
                  key: const Key('b'),
                  label: 'B',
                  isSelected: false,
                  onTap: () => tapped++,
                ),
              ],
            ),
          ),
        ),
      );

      BoxDecoration decorationOf(String key) =>
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byKey(Key(key)),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;

      final primary = AppTheme.light.colorScheme.primary;
      expect((decorationOf('a').border! as Border).top.color, primary);
      expect((decorationOf('b').border! as Border).top.color, isNot(primary));

      await tester.tap(find.byKey(const Key('b')));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    },
  );

  testWidgets('pillola scelta: velo al 18%', (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AppPill(label: 'A', isSelected: true, onTap: () {}),
          ),
        ),
      );

      final decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(decoration.color!.a, closeTo(0.18, 0.01));
    }
  });
}
