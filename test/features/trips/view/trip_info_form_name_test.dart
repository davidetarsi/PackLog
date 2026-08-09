import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/trips/view/trip_info_form.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

/// Genitore stateful che replica `add_trip_screen`/`edit_trip_info_screen`: a
/// ogni onChanged fa setState e **ripassa il nome al form come initialName**.
/// Un harness che si limita a registrare l'ultimo nome emesso non ricostruisce
/// mai il form, quindi non esercita `didUpdateWidget` — ed è lì che vivono i
/// difetti che questi test devono vedere.
class _ParentHost extends StatefulWidget {
  final String? initialName;
  final LocationSuggestionModel? destination;

  const _ParentHost({super.key, this.initialName, this.destination});

  @override
  State<_ParentHost> createState() => _ParentHostState();
}

class _ParentHostState extends State<_ParentHost> {
  String? _name;

  /// Ultimo nome emesso da onChanged, per le assert che vogliono controllare
  /// cosa il form riporta al genitore (non solo cosa c'è a video).
  String? lastName;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
  }

  /// Simula il nome che arriva dal genitore dopo il primo frame, come fa
  /// `add_trip_screen._loadTrip` in modifica: il form è già montato con
  /// initialName null e se lo vede cambiare sotto.
  void pushName(String value) => setState(() => _name = value);

  @override
  Widget build(BuildContext context) {
    return TripInfoForm(
      initialName: _name,
      initialDestinationLocation: widget.destination,
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
            setState(() {
              lastName = name;
              _name = name;
            });
          },
    );
  }
}

const _nameFieldKey = Key('trip_name_field');

Future<GlobalKey<_ParentHostState>> _pumpForm(
  WidgetTester tester, {
  String? initialName,
  String? destination,
}) async {
  final key = GlobalKey<_ParentHostState>();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: _ParentHost(
            key: key,
            initialName: initialName,
            destination: destination == null
                ? null
                : LocationSuggestionModel(
                    placeId: '',
                    displayName: destination,
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

TextField _nameField(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_nameFieldKey));

String _nameFieldText(WidgetTester tester) =>
    _nameField(tester).controller!.text;

/// Testo sotto le 3 lettere: resta sotto `minCharsForSearch` e non innesca la
/// ricerca via HTTP di LocationAutocompleteField.
Future<void> _changeDestination(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextFormField), value);
  await tester.pump();
}

void main() {
  group('TripInfoForm — nome', () {
    testWidgets(
      'un nome scritto a mano non viene sovrascritto quando cambia la destinazione',
      (tester) async {
        // È il motivo per cui esiste il flag: senza, un cambio di
        // destinazione (o di date) cancellerebbe quello che l'utente ha
        // appena scritto.
        final host = await _pumpForm(tester);

        await tester.enterText(find.byKey(_nameFieldKey), 'Da mio fratello');
        await tester.pump();

        // Cambiamo la destinazione anziché le date: le date richiedono di
        // passare dalla schermata calendario (navigazione reale, esplicitamente
        // evitata nei test), mentre la destinazione attraversa esattamente lo
        // stesso percorso di codice (_notifyChanged → _syncDerivedName), quindi
        // è equivalente per l'invariante in esame.
        await _changeDestination(tester, 'Xx');

        expect(host.currentState!.lastName, 'Da mio fratello');
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
        _nameField(tester).controller!.clear();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        final restored = _nameFieldText(tester);

        // Se _onNameFocusChanged non rimettesse _nameTouched a false dopo il
        // ripristino, il nome resterebbe congelato su `restored` anche
        // cambiando la destinazione: questo è esattamente ciò che il flag
        // dovrebbe evitare.
        await _changeDestination(tester, 'Xx');

        expect(_nameFieldText(tester), isNot(equals(restored)));
      },
    );

    testWidgets('il giro col genitore non ruba il campo mentre si digita', (
      tester,
    ) async {
      // Il difetto: svuotando il campo, _notifyChanged emette comunque il
      // nome derivato ("Roma"); il genitore fa setState, initialName cambia e
      // didUpdateWidget riscriveva il controller con "Roma" mentre l'utente
      // aveva ancora il campo sotto le dita.
      await _pumpForm(tester, destination: 'Roma');

      await tester.enterText(find.byKey(_nameFieldKey), 'Da mio fratello');
      await tester.pump();

      await tester.enterText(find.byKey(_nameFieldKey), '');
      // Due pump: il primo consegna il setState del genitore, il secondo
      // ricostruisce il form con la nuova initialName. È esattamente il frame
      // in cui il derivato ricompariva.
      await tester.pump();
      await tester.pump();

      expect(_nameField(tester).focusNode!.hasFocus, isTrue);
      expect(_nameFieldText(tester), isEmpty);
    });

    testWidgets(
      'un nome mai personalizzato continua a seguire la destinazione',
      (tester) async {
        // Il genitore monta il form senza nome e glielo passa dopo il primo
        // frame (add_trip_screen in modifica, dopo _loadTrip). Quel nome
        // coincide col derivato: non è una personalizzazione dell'utente, e
        // adottarlo non deve congelare il campo.
        final host = await _pumpForm(tester, destination: 'Roma');

        host.currentState!.pushName('Roma');
        await tester.pump();
        expect(_nameFieldText(tester), 'Roma');

        await _changeDestination(tester, 'Xx');

        expect(_nameFieldText(tester), 'Xx');
      },
    );

    testWidgets(
      'un nome iniziale che coincide col derivato non conta come personalizzato',
      (tester) async {
        // Modifica di un viaggio mai rinominato: le schermate caricano il
        // viaggio sincrono in initState, quindi initialName arriva già al
        // primo frame e il ramo che decide "personalizzato o no" è quello di
        // didChangeDependencies. Nome iniziale == derivato ⇒ non è una scelta
        // dell'utente, e il campo deve continuare a seguire la destinazione.
        await _pumpForm(tester, initialName: 'Roma', destination: 'Roma');

        expect(_nameFieldText(tester), 'Roma');

        await _changeDestination(tester, 'Xx');

        expect(_nameFieldText(tester), 'Xx');
      },
    );

    testWidgets('il derivato non resta indietro se il campo nome ha il focus', (
      tester,
    ) async {
      // Il campo viene toccato solo per leggerlo, senza digitare: la guardia
      // hasFocus impedisce di riscriverlo, ma il nome che finisce salvato non
      // deve per questo restare quello vecchio.
      final host = await _pumpForm(
        tester,
        initialName: 'Roma',
        destination: 'Roma',
      );

      await tester.tap(find.byKey(_nameFieldKey));
      await tester.pump();
      expect(_nameField(tester).focusNode!.hasFocus, isTrue);

      // Il pill azzera la destinazione senza togliere il focus al nome: è il
      // percorso con cui il difetto si raggiunge in produzione (né i pill né
      // il ritorno dal calendario fanno unfocus).
      await tester.tap(find.text('common.destination_house'));
      await tester.pump();
      await tester.pump();

      expect(_nameField(tester).focusNode!.hasFocus, isTrue);
      // Ciò che il genitore salverebbe: già il derivato nuovo, non "Roma".
      expect(host.currentState!.lastName, 'trips.unnamed_destination');

      // Il campo visibile si riallinea al blur.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();

      expect(_nameFieldText(tester), 'trips.unnamed_destination');
    });

    testWidgets('un nome personalizzato sopravvive al giro col genitore', (
      tester,
    ) async {
      final host = await _pumpForm(tester, destination: 'Roma');

      await tester.enterText(find.byKey(_nameFieldKey), 'Da mio fratello');
      await tester.pump();
      await tester.pump();

      await _changeDestination(tester, 'Xx');

      expect(_nameFieldText(tester), 'Da mio fratello');
      expect(host.currentState!.lastName, 'Da mio fratello');
    });
  });
}
