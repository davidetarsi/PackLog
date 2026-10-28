import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_floating_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Widget> items) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DsFloatingBar(children: items),
            ),
          ),
        ),
      );

  testWidgets('voci larghe uguali', (tester) async {
    await pump(tester, [
      DsBarItem(
        key: const Key('a'),
        icon: Icons.home,
        label: 'A',
        onTap: () {},
      ),
      DsBarItem(
        key: const Key('b'),
        icon: Icons.add,
        label: 'Bbbbbbbb',
        onTap: () {},
      ),
      DsBarItem(
        key: const Key('c'),
        icon: Icons.luggage,
        label: 'C',
        onTap: () {},
      ),
    ]);
    final a = tester.getSize(find.byKey(const Key('a'))).width;
    expect(tester.getSize(find.byKey(const Key('b'))).width, a);
    expect(tester.getSize(find.byKey(const Key('c'))).width, a);
  });

  testWidgets('senza onTap la voce è spenta al 50%', (tester) async {
    await pump(tester, [
      const DsBarItem(key: Key('off'), icon: Icons.delete_outline, label: 'X'),
    ]);
    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(
      icon.color,
      AppTheme.light.colorScheme.onSurface.withValues(
        alpha: AppOpacity.disabled,
      ),
    );
  });

  testWidgets('accesa e non accent: colore onSurface', (tester) async {
    await pump(tester, [
      DsBarItem(icon: Icons.delete_outline, label: 'X', onTap: () {}),
    ]);
    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(icon.color, AppTheme.light.colorScheme.onSurface);
  });

  testWidgets('la selezionata mostra la lineetta', (tester) async {
    await pump(tester, [
      DsBarItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Case',
        isSelected: true,
        onTap: () {},
      ),
    ]);
    expect(find.byKey(const Key('nav_indicator')), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
