import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/view/widgets/trip_legs_section.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<TripLeg> legs,
    required ValueChanged<List<TripLeg>> onChanged,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TripLegsSection(legs: legs, onChanged: onChanged),
      ),
    ),
  );

  group('TripLegsSection', () {
    testWidgets('senza tappe mostra solo il bottone di aggiunta', (
      tester,
    ) async {
      // Chi ha una destinazione sola non deve incontrare altro.
      await pump(tester, legs: const [], onChanged: (_) {});

      expect(find.byKey(const Key('trip_legs_add')), findsOneWidget);
      expect(find.byKey(const Key('trip_leg_row')), findsNothing);
    });

    testWidgets('mostra una riga per tappa', (tester) async {
      await pump(
        tester,
        legs: [
          TripLeg(id: 'a', locationDisplayName: 'Firenze'),
          TripLeg(id: 'b', locationDisplayName: 'Siena'),
        ],
        onChanged: (_) {},
      );

      expect(find.byKey(const Key('trip_leg_row')), findsNWidgets(2));
      expect(find.text('Firenze'), findsOneWidget);
      expect(find.text('Siena'), findsOneWidget);
    });

    testWidgets('la X rimuove la tappa e notifica la lista aggiornata', (
      tester,
    ) async {
      List<TripLeg>? updated;
      await pump(
        tester,
        legs: [
          TripLeg(id: 'a', locationDisplayName: 'Firenze'),
          TripLeg(id: 'b', locationDisplayName: 'Siena'),
        ],
        onChanged: (legs) => updated = legs,
      );

      await tester.tap(find.byKey(const Key('trip_leg_remove_a')));
      await tester.pumpAndSettle();

      expect(updated, hasLength(1));
      expect(updated!.single.id, 'b');
    });

    testWidgets(
      'la X rimuove per id anche quando due tappe hanno lo stesso nome',
      (tester) async {
        // Nomi identici e id diversi: se la rimozione filtrasse per nome
        // invece che per id (bug plausibile con una list comprehension
        // scritta male) sparirebbero entrambe le tappe, non solo quella
        // toccata.
        List<TripLeg>? updated;
        await pump(
          tester,
          legs: [
            TripLeg(id: 'a', locationDisplayName: 'Firenze'),
            TripLeg(id: 'b', locationDisplayName: 'Firenze'),
          ],
          onChanged: (legs) => updated = legs,
        );

        await tester.tap(find.byKey(const Key('trip_leg_remove_a')));
        await tester.pumpAndSettle();

        expect(updated, hasLength(1));
        expect(updated!.single.id, 'b');
      },
    );

    testWidgets(
      'la modifica sostituisce la tappa in posizione, non la sposta in fondo',
      (tester) async {
        // Tre tappe per poter distinguere davvero "in posizione" da "in
        // fondo": con due sole tappe una riscrittura come
        // `[...legs.where((l) => l.id != leg.id), updated]` produrrebbe
        // comunque una lista di 2 elementi con quella modificata per ultima,
        // indistinguibile da un semplice controllo di lunghezza.
        List<TripLeg>? updated;
        await pump(
          tester,
          legs: [
            TripLeg(id: 'a', locationDisplayName: 'Firenze'),
            TripLeg(id: 'b', locationDisplayName: 'Siena'),
            TripLeg(id: 'c', locationDisplayName: 'Roma'),
          ],
          onChanged: (legs) => updated = legs,
        );

        // Tocca la riga centrale per aprire il sheet di modifica.
        await tester.tap(find.byKey(const ValueKey('trip_leg_row_b')));
        await tester.pumpAndSettle();

        final locationField = find.descendant(
          of: find.byKey(const Key('trip_leg_sheet_location')),
          matching: find.byType(TextField),
        );
        await tester.enterText(locationField, 'Siena centro');
        await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
        await tester.pumpAndSettle();

        expect(updated, hasLength(3));
        expect(updated![0].id, 'a');
        expect(updated![1].id, 'b');
        expect(updated![1].locationDisplayName, 'Siena centro');
        expect(updated![2].id, 'c');
      },
    );
  });
}
