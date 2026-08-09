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
  });
}
