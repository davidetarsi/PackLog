import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/view/widgets/trip_leg_sheet.dart';

void main() {
  // Niente asserzioni su testo: senza EasyLocalization inizializzato `.tr()`
  // restituisce la chiave. Si cerca per Key.
  // `enterText` vuole un campo di testo, non il widget composito che lo
  // contiene: la Key sta sul LocationAutocompleteField, il TextField è dentro.
  Finder locationField() => find.descendant(
    of: find.byKey(const Key('trip_leg_sheet_location')),
    matching: find.byType(TextField),
  );

  Future<TripLeg?> openSheet(WidgetTester tester, {TripLeg? initial}) async {
    TripLeg? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showTripLegSheet(context, initial: initial);
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

  group('showTripLegSheet', () {
    testWidgets('senza luogo il salvataggio non produce una tappa', (
      tester,
    ) async {
      // Una tappa senza luogo non è un promemoria di niente.
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip_leg_sheet_location')), findsOneWidget);
    });

    testWidgets('con un luogo restituisce la tappa alla chiusura', (
      tester,
    ) async {
      TripLeg? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showTripLegSheet(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(locationField(), 'Firenze');
      await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.locationDisplayName, 'Firenze');
      expect(captured!.id, isNotEmpty);
    });

    testWidgets('in modifica conserva l identità della tappa', (tester) async {
      // L'id deve restare lo stesso, altrimenti modificare una tappa equivale
      // a cancellarla e ricrearla, e la riga salta di posto nella lista.
      TripLeg? captured;
      final initial = TripLeg(
        id: 'leg-esistente',
        locationDisplayName: 'Siena',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showTripLegSheet(context, initial: initial);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(locationField(), 'Siena centro');
      await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
      await tester.pumpAndSettle();

      expect(captured!.id, 'leg-esistente');
      expect(captured!.locationDisplayName, 'Siena centro');
    });
  });
}
