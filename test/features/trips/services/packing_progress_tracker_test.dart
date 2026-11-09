import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/features/trips/services/packing_progress_tracker.dart';

/// `now` fisso: i test sulle date devono essere deterministici.
final _now = DateTime(2026, 8, 10, 14, 30);

List<PackingEvent> _events({
  required int before,
  required int after,
  required int total,
  DateTime? departure,
}) => packingEventsFor(
  tripId: 't1',
  checkedBefore: before,
  checkedAfter: after,
  totalItems: total,
  departureDateTime: departure,
  now: _now,
);

class _Analytics extends Mock implements CoreAnalyticsService {}

void main() {
  group('sendPackingEvent', () {
    late _Analytics analytics;
    setUp(() => analytics = _Analytics());

    test('ogni evento del tracker diventa il suo metodo tipato', () {
      final events = [
        ...packingEventsFor(
          tripId: 't1',
          checkedBefore: 0,
          checkedAfter: 2,
          totalItems: 4,
          departureDateTime: null,
          now: DateTime(2026, 11, 9),
        ),
        ...packingEventsFor(
          tripId: 't1',
          checkedBefore: 3,
          checkedAfter: 4,
          totalItems: 4,
          departureDateTime: DateTime(2026, 11, 12),
          now: DateTime(2026, 11, 9),
        ),
      ];
      expect(events.map((e) => e.name).toSet(), {
        'packing_started',
        'packing_progress',
        'packing_completed',
      });
      for (final e in events) {
        expect(sendPackingEvent(analytics, e), isTrue, reason: e.name);
      }
      verify(
        () => analytics.trackPackingStarted(
          tripId: 't1',
          totalItems: 4,
          daysToDeparture: null,
        ),
      ).called(1);
      verify(
        () => analytics.trackPackingProgress(
          tripId: 't1',
          threshold: 50,
          daysToDeparture: null,
        ),
      ).called(1);
      verify(
        () => analytics.trackPackingCompleted(
          tripId: 't1',
          totalItems: 4,
          daysToDeparture: 3,
        ),
      ).called(1);
    });

    test('un nome sconosciuto non manda niente e non lancia', () {
      expect(
        sendPackingEvent(analytics, const PackingEvent('packing_paused', {})),
        isFalse,
      );
      verifyZeroInteractions(analytics);
    });

    test('proprietà malformate: non manda niente e non lancia', () {
      expect(
        sendPackingEvent(
          analytics,
          const PackingEvent('packing_started', {'trip_id': 't1'}),
        ),
        isFalse,
      );
      verifyZeroInteractions(analytics);
    });
  });

  group('packingEventsFor - inizio', () {
    test('la prima spunta emette packing_started senza soglie', () {
      final events = _events(before: 0, after: 1, total: 10);

      expect(events.map((e) => e.name), ['packing_started']);
      expect(events.first.properties['total_items'], 10);
      expect(events.first.properties['trip_id'], 't1');
    });

    test('le spunte successive non riemettono packing_started', () {
      final events = _events(before: 1, after: 2, total: 10);

      expect(events.map((e) => e.name), isNot(contains('packing_started')));
    });
  });

  group('packingEventsFor - soglie', () {
    test('attraversare il 25% emette packing_progress', () {
      final events = _events(before: 2, after: 3, total: 10);

      expect(events.map((e) => e.name), ['packing_progress']);
      expect(events.first.properties['threshold'], 25);
    });

    test('restare sotto la soglia non emette nulla', () {
      // 10% → 20%: nessuna soglia attraversata.
      expect(_events(before: 1, after: 2, total: 10), isEmpty);
    });

    test('un tap che scavalca due soglie emette solo la più alta', () {
      // Viaggio da 3 oggetti: 33% → 66%, supera sia 25 sia 50.
      final events = _events(before: 1, after: 2, total: 3);

      expect(events.map((e) => e.name), ['packing_progress']);
      expect(events.first.properties['threshold'], 50);
    });

    test('la prima spunta può emettere started e progress insieme', () {
      // Viaggio da 2 oggetti: 0% → 50%.
      final events = _events(before: 0, after: 1, total: 2);

      expect(events.map((e) => e.name), [
        'packing_started',
        'packing_progress',
      ]);
      expect(events.last.properties['threshold'], 50);
    });
  });

  group('packingEventsFor - completamento', () {
    test("l'ultima spunta emette packing_completed", () {
      final events = _events(before: 9, after: 10, total: 10);

      expect(events.map((e) => e.name), ['packing_completed']);
      expect(events.first.properties['total_items'], 10);
    });

    test('il 100% sopprime le soglie intermedie', () {
      // Viaggio da un oggetto: un tap va da 0% a 100% e attraverserebbe
      // tecnicamente tutte e tre le soglie.
      final events = _events(before: 0, after: 1, total: 1);

      expect(events.map((e) => e.name), [
        'packing_started',
        'packing_completed',
      ]);
    });
  });

  group('packingEventsFor - casi limite', () {
    test('despuntare non emette nulla', () {
      expect(_events(before: 5, after: 4, total: 10), isEmpty);
    });

    test('nessun cambiamento non emette nulla', () {
      expect(_events(before: 5, after: 5, total: 10), isEmpty);
    });

    // L'unico modo in cui questo codice potrebbe far crashare l'app.
    test('un viaggio senza oggetti non divide per zero', () {
      expect(_events(before: 0, after: 1, total: 0), isEmpty);
    });
  });

  group('packingEventsFor - days_to_departure', () {
    test('è null quando il viaggio non ha data di partenza', () {
      final events = _events(before: 0, after: 1, total: 10);

      expect(events.first.properties.containsKey('days_to_departure'), isTrue);
      expect(events.first.properties['days_to_departure'], isNull);
    });

    test('conta i giorni interi, non le ore', () {
      // `now` è alle 14:30; la partenza è il giorno dopo alle 9:00. Confrontare
      // gli istanti darebbe 0 giorni, confrontare le date dà 1.
      final events = _events(
        before: 0,
        after: 1,
        total: 10,
        departure: DateTime(2026, 8, 11, 9),
      );

      expect(events.first.properties['days_to_departure'], 1);
    });

    test('è negativo se si spunta dopo la partenza', () {
      final events = _events(
        before: 0,
        after: 1,
        total: 10,
        departure: DateTime(2026, 8, 8),
      );

      expect(events.first.properties['days_to_departure'], -2);
    });
  });
}
