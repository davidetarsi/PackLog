import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  testWidgets('errore: testo sotto il campo e bordo rosso', (tester) async {
    await pump(tester, const DsTextField(errorText: 'Serve un nome'));

    expect(find.text('Serve un nome'), findsOneWidget);
    final decoration = tester
        .widget<InputDecorator>(find.byType(InputDecorator))
        .decoration;
    expect(decoration.errorText, 'Serve un nome');
    final errorBorder = decoration.errorBorder as OutlineInputBorder;
    expect(errorBorder.borderSide.color, AppTheme.light.colorScheme.error);
    expect(errorBorder.borderSide.width, 1.5);
  });

  testWidgets('validator: il messaggio compare dopo la digitazione', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: DsTextField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Serve un nome' : null,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'a');
    await tester.pump();
    expect(find.text('Serve un nome'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
    expect(find.text('Serve un nome'), findsOneWidget);
  });

  testWidgets('aiuto sotto il campo', (tester) async {
    await pump(tester, const DsTextField(helperText: 'Lo vedi solo tu'));
    expect(find.text('Lo vedi solo tu'), findsOneWidget);
  });

  testWidgets('maxLength: si ferma senza contatore', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pump(tester, DsTextField(controller: controller, maxLength: 5));

    await tester.enterText(find.byType(TextFormField), 'abcdefg');
    await tester.pump();

    expect(controller.text, 'abcde');
    expect(find.textContaining('/5'), findsNothing);
  });

  testWidgets('icona a sinistra', (tester) async {
    await pump(tester, const DsTextField(prefixIcon: Icons.edit_outlined));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('invio chiama onSubmitted', (tester) async {
    String? submitted;
    await pump(tester, DsTextField(onSubmitted: (value) => submitted = value));

    await tester.enterText(find.byType(TextFormField), 'ciao');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, 'ciao');
  });

  testWidgets('la chiave del widget basta per scrivere', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pump(
      tester,
      DsTextField(key: const Key('k'), controller: controller),
    );

    await tester.enterText(find.byKey(const Key('k')), 'ciao');
    await tester.pump();

    expect(controller.text, 'ciao');
  });

  testWidgets('errore lungo con testo a 2.0 va a capo', (tester) async {
    const longError =
        'Il nome non può superare i caratteri consentiti, scegline uno più '
        'breve e riprova con una parola diversa per questo campo, grazie.';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DsTextField(errorText: longError),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(longError), findsOneWidget);
  });
}
