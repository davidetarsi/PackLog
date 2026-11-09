import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';
import 'package:pack_log/shared/widgets/ds_text_button.dart';

void main() {
  for (final (width, scale) in [(320.0, 1.0), (390.0, 1.0), (320.0, 1.6)]) {
    testWidgets('titolo lungo: X in alto e azione a destra ($width, $scale)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: DsSheetHeader(
              title: 'Mocassini eleganti per il viaggio ×1',
              onClose: () {},
              actions: [DsTextButton(label: 'Da comprare', onPressed: () {})],
            ),
          ),
        ),
      );
      final title = tester.getRect(
        find.text('Mocassini eleganti per il viaggio ×1'),
      );
      final close = tester.getRect(find.byKey(const Key('sheet_close')));
      final action = tester.getRect(
        find.widgetWithText(TextButton, 'Da comprare'),
      );
      expect(close.top, lessThanOrEqualTo(title.top + 1));
      expect(action.right, closeTo(close.left, 0.01));
      expect(tester.takeException(), isNull);
    });
  }
}
