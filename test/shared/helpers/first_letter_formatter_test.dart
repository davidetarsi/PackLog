import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/helpers/first_letter_formatter.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_field.dart';

void main() {
  const formatter = FirstLetterFormatter();

  TextEditingValue run(String text, {int? caret}) => formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    ),
  );

  test('la prima lettera diventa maiuscola, il resto non cambia', () {
    expect(run('aux bt').text, 'Aux bt');
    expect(run('maglione di lana').text, 'Maglione di lana');
    expect(run('t-shirt bIANCA').text, 'T-shirt bIANCA');
  });

  test('già maiuscola, vuoto o senza lettera iniziale: nessuna modifica', () {
    expect(run('Aux bt').text, 'Aux bt');
    expect(run('').text, '');
    expect(run('3 paia di calzini').text, '3 paia di calzini');
    expect(run('  borraccia').text, '  Borraccia');
  });

  test('il cursore resta dov\'era', () {
    expect(run('aux bt', caret: 3).selection.baseOffset, 3);
  });

  test('lettere che cambiano lunghezza in maiuscolo restano com\'erano', () {
    expect(run('ßtrumpf').text, 'ßtrumpf');
  });

  testWidgets('DsTextField con sentences: "aux bt" diventa "Aux bt"', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DsTextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'aux bt');
    expect(controller.text, 'Aux bt');
  });

  testWidgets('DsTextField senza sentences non tocca il testo', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: DsTextField(controller: controller)),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'aux bt');
    expect(controller.text, 'aux bt');
  });
}
