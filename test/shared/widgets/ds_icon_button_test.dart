import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_icon_button.dart';

/// [DsIconButton] è il bottone di sola icona: ha sempre un tooltip, un'area di
/// tocco di 48 e lo stato spento al 50%.
void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    VoidCallback? onPressed,
    String tooltip = 'Chiudi',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: DsIconButton(
              icon: Icons.close,
              tooltip: tooltip,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tooltip obbligatorio e visibile al tocco lungo', (tester) async {
    await pumpButton(tester, onPressed: () {});

    expect(find.byTooltip('Chiudi'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DsIconButton)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Chiudi'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('spento al 50%', (tester) async {
    await pumpButton(tester, onPressed: null);

    final color = IconTheme.of(tester.element(find.byIcon(Icons.close))).color;
    final expected = Theme.of(
      tester.element(find.byType(DsIconButton)),
    ).colorScheme.onSurface.withValues(alpha: AppOpacity.disabled);
    expect(color, expected);
  });

  testWidgets('area di tocco 48', (tester) async {
    await pumpButton(tester, onPressed: () {});

    final size = tester.getSize(find.byType(DsIconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
