import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_dialog.dart';
import 'package:pack_log/shared/widgets/ds_text_button.dart';

/// [DsDialog] è la cornice di tutti i dialoghi: titolo, messaggio e azioni
/// arrivano dal chiamante, forma e spaziature sono decise qui.
void main() {
  Widget app({Widget? home, double textScale = 1}) {
    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home ?? const _Host(dialog: _emptyDialog),
    );
  }

  testWidgets('titolo, messaggio e due azioni', (tester) async {
    await tester.pumpWidget(
      app(
        home: _Host(
          dialog: (dialogContext) => DsDialog(
            title: 'Eliminare la casa?',
            message: 'Non si torna indietro.',
            actions: [
              DsDialog.twoActions(
                cancelLabel: 'Annulla',
                onCancel: () => Navigator.pop(dialogContext, false),
                confirmLabel: 'Elimina',
                onConfirm: () => Navigator.pop(dialogContext, true),
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare la casa?'), findsOneWidget);
    expect(find.text('Non si torna indietro.'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
    expect(find.text('Elimina'), findsOneWidget);
    expect(find.byType(DsButton), findsNWidgets(2));

    // Il titolo è titleLarge con peso w700 (`.title`).
    final title = tester.widget<Text>(find.text('Eliminare la casa?'));
    expect(title.style?.fontWeight, FontWeight.w700);

    // Due azioni affiancate, non impilate.
    final cancel = tester.getRect(find.text('Annulla'));
    final confirm = tester.getRect(find.text('Elimina'));
    expect(cancel.top, closeTo(confirm.top, 1.0));
    expect(cancel.right, lessThanOrEqualTo(confirm.left));
  });

  testWidgets("un'azione sola prende tutta la larghezza", (tester) async {
    await tester.pumpWidget(
      app(
        home: _Host(
          dialog: (dialogContext) => DsDialog(
            title: 'Ok',
            message: 'Messaggio',
            actions: [
              DsTextButton(
                label: 'Chiudi',
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Il bottone riempie la riga dell'azione, che è più larga di qualunque
    // etichetta corta (un bottone a contenuto sarebbe largo meno di 100).
    final slot = tester.getRect(
      find
          .ancestor(
            of: find.byType(DsTextButton),
            matching: find.byType(Expanded),
          )
          .first,
    );
    final action = tester.getRect(find.byType(DsTextButton));
    expect(action.width, closeTo(slot.width, 1.0));
    expect(slot.width, greaterThan(200));
  });

  testWidgets('doppio tocco veloce su Elimina chiude una volta sola', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      app(home: const Scaffold(body: Text('Pagina di base'))),
    );

    // Una pagina spinta sopra quella di base, con il dialogo aperto sopra.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Pagina spinta')),
      ),
    );
    await tester.pumpAndSettle();

    final pageContext = tester.element(find.text('Pagina spinta'));
    showDsDialog<bool>(
      pageContext,
      builder: (dialogContext) => DsDialog(
        title: 'Eliminare?',
        actions: [
          DsDialog.twoActions(
            cancelLabel: 'Annulla',
            onCancel: () => Navigator.pop(dialogContext, false),
            confirmLabel: 'Elimina',
            onConfirm: () => Navigator.pop(dialogContext, true),
            isDestructive: true,
          ),
        ],
      ),
    ).then((value) => result = value);
    await tester.pumpAndSettle();

    // Due tocchi di fila sul bottone di conferma, senza pump in mezzo: come
    // un doppio tocco reale, che arriva prima che il dialogo esca.
    final confirm = tester.getCenter(find.text('Elimina'));
    for (var i = 0; i < 2; i++) {
      final gesture = await tester.createGesture();
      await gesture.down(confirm);
      await gesture.up();
    }
    await tester.pumpAndSettle();

    // Il secondo tocco non deve chiudere anche la pagina sotto.
    expect(find.text('Pagina spinta'), findsOneWidget);
    expect(find.byType(DsDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('la conferma ignora i tocchi dopo il primo', (tester) async {
    var confirms = 0;
    var cancels = 0;
    await tester.pumpWidget(
      app(
        home: Scaffold(
          body: Center(
            child: DsDialog.twoActions(
              cancelLabel: 'Annulla',
              onCancel: () => cancels++,
              confirmLabel: 'Elimina',
              onConfirm: () => confirms++,
              isDestructive: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Elimina'));
    await tester.tap(find.text('Elimina'));
    await tester.tap(find.text('Elimina'));
    expect(confirms, 1);

    // La scelta è una sola anche se l'altro bottone arriva dopo.
    await tester.tap(find.text('Annulla'));
    expect(cancels, 0);
  });

  testWidgets('etichette lunghe con testo a 2.0 su 320: niente overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      app(
        textScale: 2.0,
        home: _Host(
          dialog: (dialogContext) => DsDialog(
            title: 'Eliminare definitivamente tutto il contenuto del viaggio',
            message: 'Messaggio lungo che va a capo più volte.',
            actions: [
              DsDialog.twoActions(
                cancelLabel: 'No, torna indietro e controlla',
                onCancel: () => Navigator.pop(dialogContext, false),
                confirmLabel: 'Elimina definitivamente tutto',
                onConfirm: () => Navigator.pop(dialogContext, true),
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DsButton), findsNWidgets(2));
  });

  testWidgets('barrierDismissible false: il tocco fuori non chiude', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(home: const _Host(barrierDismissible: false, dialog: _emptyDialog)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(DsDialog), findsOneWidget);
  });

  testWidgets('barrierDismissible true (default): il tocco fuori chiude', (
    tester,
  ) async {
    await tester.pumpWidget(app(home: const _Host(dialog: _emptyDialog)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(DsDialog), findsNothing);
  });
}

Widget _emptyDialog(BuildContext context) => const DsDialog(title: 'Titolo');

/// Pagina con un bottone "open" che apre il dialogo passato.
class _Host extends StatelessWidget {
  final WidgetBuilder dialog;
  final bool barrierDismissible;

  const _Host({required this.dialog, this.barrierDismissible = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showDsDialog<void>(
              context,
              builder: dialog,
              barrierDismissible: barrierDismissible,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}
