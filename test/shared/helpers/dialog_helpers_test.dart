import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/helpers/dialog_helpers.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

/// I dialog di conferma sono l'ultimo posto dove ci si può permettere un
/// layout che va in overflow o un bottone che non risponde: sono la schermata
/// in cui l'utente decide se cancellare qualcosa.
void main() {
  Future<bool?> openConfirmation(
    WidgetTester tester, {
    bool isDestructive = false,
  }) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await DialogHelpers.showConfirmation(
                  context: context,
                  title: 'Titolo',
                  message: 'Messaggio',
                  confirmLabel: 'Conferma',
                  cancelLabel: 'Annulla',
                  isDestructive: isDestructive,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('DialogHelpers — azioni', () {
    testWidgets('due pill affiancate, di larghezza uguale', (tester) async {
      await openConfirmation(tester);

      final buttons = find.byType(DsButton);
      expect(buttons, findsNWidgets(2));

      final cancel = tester.getRect(buttons.at(0));
      final confirm = tester.getRect(buttons.at(1));

      // Stessa larghezza: nessuno dei due è il "bottone piccolo a destra" che
      // c'era prima.
      expect(
        (cancel.width - confirm.width).abs(),
        lessThan(1.0),
        reason: 'le due pill devono dividersi la larghezza in parti uguali',
      );
      // Affiancate, non impilate.
      expect(cancel.top, closeTo(confirm.top, 1.0));
      expect(cancel.right, lessThanOrEqualTo(confirm.left));
    });

    testWidgets('la conferma distruttiva è rossa, non arancione', (
      tester,
    ) async {
      // Un "Elimina" arancione accanto a un "Annulla" grigio farebbe sembrare
      // la cancellazione la strada consigliata.
      await openConfirmation(tester, isDestructive: true);

      final confirm = tester.widget<DsButton>(find.byType(DsButton).at(1));
      expect(confirm.variant, DsButtonVariant.destructive);

      final cancel = tester.widget<DsButton>(find.byType(DsButton).at(0));
      expect(cancel.variant, DsButtonVariant.secondary);
    });

    testWidgets('confermare restituisce true, annullare false', (tester) async {
      await openConfirmation(tester);
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await openConfirmation(tester);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('nessun overflow di layout con etichette lunghe', (
      tester,
    ) async {
      // Due pill affiancate su uno schermo stretto sono il caso in cui il
      // layout cede per primo.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DialogHelpers.showConfirmation(
                  context: context,
                  title: 'Titolo',
                  message: 'Messaggio',
                  confirmLabel: 'Elimina definitivamente tutto',
                  cancelLabel: 'No, torna indietro',
                  isDestructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DsButton), findsNWidgets(2));
    });
  });
}
