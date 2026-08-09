import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/trips/view/trip_info_form.dart';

void main() {
  Future<String?> pumpAndReadName(
    WidgetTester tester, {
    String? initialName,
    required Future<void> Function(WidgetTester tester) act,
  }) async {
    String? lastName;
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
                    lastName = name;
                  },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await act(tester);
    return lastName;
  }

  group('TripInfoForm — nome', () {
    testWidgets('un nome scritto a mano non viene sovrascritto', (
      tester,
    ) async {
      // È il motivo per cui esiste il flag: senza, cambiare destinazione
      // cancellerebbe quello che l'utente ha appena scritto.
      final name = await pumpAndReadName(
        tester,
        act: (tester) async {
          await tester.enterText(
            find.byKey(const Key('trip_name_field')),
            'Da mio fratello',
          );
          await tester.pumpAndSettle();
        },
      );

      expect(name, 'Da mio fratello');
    });

    testWidgets('svuotare il campo e uscirne ripristina il nome derivato', (
      tester,
    ) async {
      await pumpAndReadName(
        tester,
        initialName: 'Roma',
        act: (tester) async {
          await tester.enterText(find.byKey(const Key('trip_name_field')), '');
          await tester.pumpAndSettle();
          // Perdita di focus: il fallback scatta qui, non al salvataggio,
          // altrimenti il campo resterebbe visibilmente vuoto.
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        },
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('trip_name_field')),
      );
      expect(field.controller!.text, isNotEmpty);
    });
  });
}
