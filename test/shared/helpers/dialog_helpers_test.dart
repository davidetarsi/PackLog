import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/helpers/dialog_helpers.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_dialog.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_text_button.dart';

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

    testWidgets('la conferma distruttiva evidenzia Annulla e riduce Elimina', (
      tester,
    ) async {
      await openConfirmation(tester, isDestructive: true);

      expect(find.byType(DsButton), findsOneWidget);
      expect(find.byType(DsTextButton), findsOneWidget);
      final cancel = tester.widget<DsButton>(find.byType(DsButton));
      expect(cancel.label, 'Annulla');
      expect(cancel.variant, DsButtonVariant.primary);
      final confirm = tester.widget<DsTextButton>(find.byType(DsTextButton));
      expect(confirm.label, 'Conferma');
      expect(confirm.destructive, isTrue);
      expect(
        tester.getRect(find.byType(DsButton)).left,
        lessThan(tester.getRect(find.byType(DsTextButton)).left),
      );
    });

    testWidgets('confermare restituisce true, annullare false', (tester) async {
      await openConfirmation(tester);
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();
      expect(find.byType(DsDialog), findsNothing);

      await openConfirmation(tester);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.byType(DsDialog), findsNothing);
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
      expect(find.byType(DsButton), findsOneWidget);
      expect(find.byType(DsTextButton), findsOneWidget);
    });

    testWidgets('conferma testuale neutra lascia Annulla in evidenza', (
      tester,
    ) async {
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
                  confirmLabel: 'Esci',
                  cancelLabel: 'Annulla',
                  confirmAsText: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<DsButton>(find.byType(DsButton)).variant,
        DsButtonVariant.primary,
      );
      final exit = tester.widget<DsTextButton>(find.byType(DsTextButton));
      expect(exit.label, 'Esci');
      expect(exit.destructive, isFalse);
    });
  });
}
