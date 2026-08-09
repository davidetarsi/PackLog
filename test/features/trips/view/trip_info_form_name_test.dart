import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/trips/view/trip_info_form.dart';

/// Raccoglie l'ultimo nome emesso da onChanged, per le assert che vogliono
/// controllare cosa il form riporta al genitore (non solo cosa c'è a video).
class _Harness {
  String? lastName;
}

const _nameFieldKey = Key('trip_name_field');

Future<_Harness> _pumpForm(WidgetTester tester, {String? initialName}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TripInfoForm(
            initialName: initialName,
            onChanged:
                ({
                  description,
                  departureDateTime,
                  returnDateTime,
                  destinationHouseId,
                  destinationLocation,
                  destinationName,
                  name,
                }) {
                  harness.lastName = name;
                },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

String _nameFieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_nameFieldKey)).controller!.text;

void main() {
  group('TripInfoForm — nome', () {
    testWidgets(
      'un nome scritto a mano non viene sovrascritto quando cambia la destinazione',
      (tester) async {
        // È il motivo per cui esiste il flag: senza, un cambio di
        // destinazione (o di date) cancellerebbe quello che l'utente ha
        // appena scritto.
        final harness = await _pumpForm(tester);

        await tester.enterText(find.byKey(_nameFieldKey), 'Da mio fratello');
        await tester.pump();

        // Cambiamo la destinazione anziché le date: le date richiedono di
        // passare dalla schermata calendario (navigazione reale, esplicitamente
        // evitata nei test), mentre la destinazione attraversa esattamente lo
        // stesso percorso di codice (_notifyChanged → _syncDerivedName), quindi
        // è equivalente per l'invariante in esame. Testo sotto le 3 lettere
        // per restare sotto minCharsForSearch e non innescare la ricerca via
        // HTTP di LocationAutocompleteField.
        await tester.enterText(find.byType(TextFormField), 'Xx');
        await tester.pump();

        expect(harness.lastName, 'Da mio fratello');
        expect(_nameFieldText(tester), 'Da mio fratello');
      },
    );

    testWidgets(
      'svuotare il campo lo lascia vuoto finché non perde il focus, poi ripristina il derivato',
      (tester) async {
        await _pumpForm(tester, initialName: 'Roma');

        await tester.enterText(find.byKey(_nameFieldKey), '');
        await tester.pump();

        // Prima del blur: se _syncDerivedName riscrivesse il controller
        // mentre l'utente ha ancora il focus sul campo, qui il campo
        // risulterebbe già pieno e l'assert lo scoprirebbe.
        expect(_nameFieldText(tester), isEmpty);

        // Perdita di focus: il fallback scatta qui, non al salvataggio,
        // altrimenti il campo resterebbe visibilmente vuoto per tutta la
        // compilazione.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(_nameFieldText(tester), isNotEmpty);
      },
    );

    testWidgets(
      'dopo il ripristino al blur, cambiare la destinazione aggiorna di nuovo il nome derivato',
      (tester) async {
        await _pumpForm(tester);

        // Scriviamo un nome per touchare il flag (_nameTouched = true), poi
        // svuotiamo il controller DIRETTAMENTE — bypassando l'onChanged del
        // TextField — perché quell'onChanged resetterebbe da solo
        // _nameTouched su testo vuoto, mascherando l'effetto della riga che
        // vogliamo isolare. Solo così il blur che segue passa da
        // _onNameFocusChanged con touched=true e testo vuoto: l'unica cosa
        // che può rimettere il flag a false a questo punto è la riga
        // `_nameTouched = false;` dentro _onNameFocusChanged.
        await tester.enterText(find.byKey(_nameFieldKey), 'Milano');
        await tester.pump();
        tester.widget<TextField>(find.byKey(_nameFieldKey)).controller!.clear();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        final restored = _nameFieldText(tester);

        // Se _onNameFocusChanged non rimettesse _nameTouched a false dopo il
        // ripristino, il nome resterebbe congelato su `restored` anche
        // cambiando la destinazione: questo è esattamente ciò che il flag
        // dovrebbe evitare.
        await tester.enterText(find.byType(TextFormField), 'Xx');
        await tester.pump();

        expect(_nameFieldText(tester), isNot(equals(restored)));
      },
    );
  });
}
