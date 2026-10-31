import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_motion.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_appear.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {bool? noAnimations}) {
    final app = MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
    if (noAnimations == null) return tester.pumpWidget(app);
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: noAnimations),
        child: app,
      ),
    );
  }

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(DsAppear),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('a 0 ms l opacità è 0', (tester) async {
    await pump(tester, const DsAppear(child: Text('Felpa')));
    expect(opacity(tester), 0);
    expect(find.text('Felpa'), findsOneWidget);
  });

  testWidgets('a AppMotion.slow l opacità è 1', (tester) async {
    await pump(tester, const DsAppear(child: Text('Felpa')));
    await tester.pump(AppMotion.slow);
    expect(opacity(tester), 1);
  });

  testWidgets('a metà corsa è tra 0 e 1', (tester) async {
    await pump(tester, const DsAppear(child: Text('Felpa')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(tester), greaterThan(0));
    expect(opacity(tester), lessThan(1));
  });

  testWidgets('con le animazioni disattivate compare subito', (tester) async {
    await pump(
      tester,
      const DsAppear(child: Text('Felpa')),
      noAnimations: true,
    );
    expect(opacity(tester), 1);
  });

  testWidgets('con la stessa chiave un nuovo build non la fa ripartire', (
    tester,
  ) async {
    const key = ValueKey('item-1');
    await pump(tester, const DsAppear(key: key, child: Text('Felpa')));
    await tester.pump(const Duration(milliseconds: 150));
    final before = opacity(tester);

    await pump(tester, const DsAppear(key: key, child: Text('Felpa verde')));
    await tester.pump();
    expect(opacity(tester), before);
    expect(find.text('Felpa verde'), findsOneWidget);
  });
}
