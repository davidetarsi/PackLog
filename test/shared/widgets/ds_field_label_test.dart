import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_field_label.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('la variante evidente usa titleMedium semibold onSurface', (
    tester,
  ) async {
    await pump(tester, const DsFieldLabel.prominent('Dettagli'));
    final text = tester.widget<Text>(find.text('Dettagli'));
    final cs = AppTheme.light.colorScheme;
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.color, cs.onSurface);
    expect(
      text.style!.fontSize,
      AppTheme.light.textTheme.titleMedium!.fontSize,
    );
  });

  testWidgets('la variante normale resta labelLarge onSurfaceVariant', (
    tester,
  ) async {
    await pump(tester, const DsFieldLabel('Nome'));
    final text = tester.widget<Text>(find.text('Nome'));
    expect(text.style!.color, AppTheme.light.colorScheme.onSurfaceVariant);
    expect(
      text.style!.fontWeight,
      AppTheme.light.textTheme.labelLarge!.fontWeight,
    );
  });
}
