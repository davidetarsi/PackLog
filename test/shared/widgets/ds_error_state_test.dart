import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_error_state.dart';

void main() {
  testWidgets('nasconde dettagli tecnici e permette di riprovare', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DsErrorState(
            error: StateError('SQL secret internal'),
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(find.textContaining('SQL secret internal'), findsNothing);
    expect(find.text('errors.load_failed'), findsOneWidget);
    await tester.tap(find.text('common.retry'));
    expect(retries, 1);
  });

  testWidgets('su uno spazio basso il messaggio resta scorrevole', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            height: 140,
            child: DsErrorState(
              error: Exception('internal'),
              message: 'Un messaggio lungo ' * 20,
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('common.retry'));
    expect(tester.takeException(), isNull);
  });
}
