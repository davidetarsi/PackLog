import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/ds_dashed_box.dart';

void main() {
  testWidgets('DsDashedBox disegna il bordo tratteggiato attorno al figlio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DsDashedBox(child: Text('Nuova casa'))),
      ),
    );
    expect(find.text('Nuova casa'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DsDashedBox),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });
}
