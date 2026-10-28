import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_section_title.dart';

void main() {
  testWidgets('DsSectionTitle pesa w700', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DsSectionTitle('Dove vai?')),
      ),
    );
    final text = tester.widget<Text>(find.text('Dove vai?'));
    expect(text.style!.fontWeight, FontWeight.w700);
  });
}
