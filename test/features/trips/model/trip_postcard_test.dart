import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_postcard.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

TripModel makeTrip(
  String id, {
  DateTime? departure,
  DateTime? returnAt,
  DateTime? createdAt,
  bool saved = false,
  List<TripItem> items = const [],
  LocationSuggestionModel? destination,
  List<TripLeg> legs = const [],
}) {
  return TripModel(
    id: id,
    name: 'Trip $id',
    departureDateTime: departure,
    returnDateTime: returnAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isSaved: saved,
    items: items,
    destinationLocation: destination,
    legs: legs,
  );
}

TripItem makeItem(String id, {bool checked = false}) {
  return TripItem(
    id: id,
    name: 'Item $id',
    category: ItemCategory.varie,
    quantity: 1,
    isChecked: checked,
  );
}

TripLeg makeLeg(String id, String name, {DateTime? from, DateTime? to}) {
  return TripLeg(id: id, locationDisplayName: name, from: from, to: to);
}

void main() {
  final lisbona = LocationSuggestionModel(
    placeId: 'p',
    displayName: 'Lisbona, Portogallo',
  );

  group('buildItinerary', () {
    test('viaggio senza tappe: Andata, meta, Ritorno', () {
      final departure = DateTime(2026, 10, 28, 9);
      final returnAt = DateTime(2026, 10, 31, 8);
      final trip = makeTrip(
        't1',
        departure: departure,
        returnAt: returnAt,
        destination: lisbona,
      );

      final entries = buildItinerary(trip, destination: 'Lisbona');

      expect(entries.map((e) => e.kind).toList(), [
        ItineraryKind.departure,
        ItineraryKind.place,
        ItineraryKind.ret,
      ]);
      final place = entries[1];
      expect(place.name, 'Lisbona');
      expect(place.from, departure);
      expect(place.to, returnAt);
      expect(entries[0].date, departure);
      expect(entries[2].date, returnAt);
    });

    test('tappe datate e senza date: meta fino alla prima tappa', () {
      final departure = DateTime(2026, 10, 10, 9);
      final returnAt = DateTime(2026, 10, 15, 8);
      final trip = makeTrip(
        't2',
        departure: departure,
        returnAt: returnAt,
        destination: lisbona,
        legs: [
          makeLeg('porto', 'Porto'),
          makeLeg(
            'sintra',
            'Sintra, Portogallo',
            from: DateTime(2026, 10, 13, 10),
            to: DateTime(2026, 10, 15, 10),
          ),
        ],
      );

      final entries = buildItinerary(trip, destination: 'Lisbona');

      expect(entries.map((e) => e.kind).toList(), [
        ItineraryKind.departure,
        ItineraryKind.place,
        ItineraryKind.transfer,
        ItineraryKind.place,
        ItineraryKind.transfer,
        ItineraryKind.place,
        ItineraryKind.ret,
      ]);
      final meta = entries[1];
      expect(meta.from, departure);
      expect(meta.to, DateTime(2026, 10, 13, 10));
      expect(entries[2].date, DateTime(2026, 10, 13, 10));
      expect(entries[3].name, 'Sintra');
      final last = entries[5];
      expect(last.name, 'Porto');
      expect(last.from, isNull);
    });

    test('sole tappe senza date: la meta arriva fino al ritorno', () {
      final returnAt = DateTime(2026, 10, 15, 8);
      final trip = makeTrip(
        't5',
        departure: DateTime(2026, 10, 10, 9),
        returnAt: returnAt,
        destination: lisbona,
        legs: [makeLeg('porto', 'Porto')],
      );

      final entries = buildItinerary(trip, destination: 'Lisbona');

      final meta = entries[1];
      expect(meta.kind, ItineraryKind.place);
      expect(meta.to, returnAt);
    });

    test('più di maxPlaces luoghi: riassume le tappe centrali', () {
      final trip = makeTrip(
        't3',
        departure: DateTime(2026, 10, 10, 9),
        returnAt: DateTime(2026, 10, 20, 8),
        destination: lisbona,
        legs: [
          makeLeg(
            'a',
            'Sintra',
            from: DateTime(2026, 10, 12),
            to: DateTime(2026, 10, 13),
          ),
          makeLeg(
            'b',
            'Cascais',
            from: DateTime(2026, 10, 14),
            to: DateTime(2026, 10, 15),
          ),
          makeLeg(
            'c',
            'Porto',
            from: DateTime(2026, 10, 16),
            to: DateTime(2026, 10, 18),
          ),
        ],
      );

      final entries = buildItinerary(
        trip,
        destination: 'Lisbona',
        maxPlaces: 3,
      );

      expect(entries.map((e) => e.kind).toList(), [
        ItineraryKind.departure,
        ItineraryKind.place,
        ItineraryKind.moreStops,
        ItineraryKind.transfer,
        ItineraryKind.place,
        ItineraryKind.ret,
      ]);
      expect(entries[2].hiddenStops, 2);
      expect(entries[4].name, 'Porto');
      expect(entries[3].date, DateTime(2026, 10, 16));
    });

    test('viaggio senza date: nessuna data e nessuna notte', () {
      final trip = makeTrip('t4', destination: lisbona);

      final entries = buildItinerary(trip, destination: 'Lisbona');

      expect(entries[0].kind, ItineraryKind.departure);
      expect(entries[0].date, isNull);
      expect(entries.last.kind, ItineraryKind.ret);
      expect(entries.last.date, isNull);
      final place = entries[1];
      expect(nightsBetween(place.from, place.to), isNull);
    });

    test('tappe con la stessa partenza: ordine d ingresso', () {
      final trip = makeTrip(
        't6',
        departure: DateTime(2026, 10, 10, 9),
        returnAt: DateTime(2026, 10, 20, 8),
        destination: lisbona,
        legs: [
          makeLeg('sintra', 'Sintra, Portogallo', from: DateTime(2026, 10, 12)),
          makeLeg(
            'cascais',
            'Cascais, Portogallo',
            from: DateTime(2026, 10, 12),
          ),
        ],
      );

      final entries = buildItinerary(trip, destination: 'Lisbona');

      final places = entries
          .where((e) => e.kind == ItineraryKind.place)
          .map((e) => e.name)
          .toList();
      expect(places, ['Lisbona', 'Sintra', 'Cascais']);
    });
  });

  group('buildItinerary con case', () {
    test('tappa con casa: mostra il nome della casa, intero', () {
      final trip = makeTrip(
        'h1',
        departure: DateTime(2026, 10, 10, 9),
        returnAt: DateTime(2026, 10, 20, 8),
        destination: lisbona,
        legs: [
          TripLeg(
            id: 'casa',
            locationDisplayName: 'Via Roma, Cagliari, Italia',
            houseId: 'h1',
            from: DateTime(2026, 10, 12),
          ),
        ],
      );

      final entries = buildItinerary(
        trip,
        destination: 'Lisbona',
        houseNames: {'h1': 'Casa al mare, Sardegna'},
      );

      final names = entries
          .where((e) => e.kind == ItineraryKind.place)
          .map((e) => e.name)
          .toList();
      expect(names, ['Lisbona', 'Casa al mare, Sardegna']);
    });

    test('tappa con casa senza mappa: usa legPlaceName', () {
      final trip = makeTrip(
        'h2',
        departure: DateTime(2026, 10, 10, 9),
        returnAt: DateTime(2026, 10, 20, 8),
        destination: lisbona,
        legs: [
          TripLeg(
            id: 'casa',
            locationDisplayName: 'Via Roma, Cagliari, Italia',
            houseId: 'h1',
            from: DateTime(2026, 10, 12),
          ),
        ],
      );

      final entries = buildItinerary(trip, destination: 'Lisbona');

      final names = entries
          .where((e) => e.kind == ItineraryKind.place)
          .map((e) => e.name)
          .toList();
      expect(names, ['Lisbona', 'Via Roma']);
    });

    test('casa non presente nella mappa: usa legPlaceName', () {
      final trip = makeTrip(
        'h3',
        departure: DateTime(2026, 10, 10, 9),
        returnAt: DateTime(2026, 10, 20, 8),
        destination: lisbona,
        legs: [
          TripLeg(
            id: 'casa',
            locationDisplayName: 'Sintra, Portogallo',
            houseId: 'sconosciuta',
            from: DateTime(2026, 10, 12),
          ),
        ],
      );

      final entries = buildItinerary(
        trip,
        destination: 'Lisbona',
        houseNames: {'h1': 'Casa al mare'},
      );

      final names = entries
          .where((e) => e.kind == ItineraryKind.place)
          .map((e) => e.name)
          .toList();
      expect(names, ['Lisbona', 'Sintra']);
    });
  });

  group('ItineraryEntry', () {
    test('uguaglianza per valore', () {
      const a = ItineraryEntry(kind: ItineraryKind.moreStops, hiddenStops: 2);
      const b = ItineraryEntry(kind: ItineraryKind.moreStops, hiddenStops: 2);
      const c = ItineraryEntry(kind: ItineraryKind.moreStops, hiddenStops: 3);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('legPlaceName', () {
    test('restituisce il nome prima della prima virgola', () {
      expect(legPlaceName(makeLeg('x', 'Sintra, Portogallo')), 'Sintra');
    });
  });

  group('postcardTitle', () {
    test('usa il nome del viaggio', () {
      final trip = makeTrip('t1', destination: lisbona);

      expect(postcardTitle(trip, destination: 'Lisbona'), 'Trip t1');
    });

    test('senza nome usa la meta', () {
      final trip = makeTrip('t2').copyWith(name: '  ');

      expect(postcardTitle(trip, destination: 'Lisbona'), 'Lisbona');
    });
  });

  group('tripDestinationName', () {
    test('usa il nome intero della casa senza tagli', () {
      final trip = makeTrip('d1', destination: lisbona);

      expect(
        tripDestinationName(
          trip,
          houseName: "Baita dei nonni a Courmayeur, Valle d'Aosta",
        ),
        "Baita dei nonni a Courmayeur, Valle d'Aosta",
      );
    });

    test('senza casa usa la parte prima della virgola della località', () {
      final trip = makeTrip('d2', destination: lisbona);

      expect(tripDestinationName(trip), 'Lisbona');
    });

    test('preferisce la città quando presente', () {
      final trip = makeTrip(
        'd3',
        destination: LocationSuggestionModel(
          placeId: 'p',
          displayName: 'Sintra, Lisbona, Portogallo',
          city: 'Sintra',
        ),
      );

      expect(tripDestinationName(trip), 'Sintra');
    });

    test('senza meta restituisce il nome del viaggio', () {
      final trip = makeTrip('d4');

      expect(tripDestinationName(trip), 'Trip d4');
    });

    test('casa vuota viene ignorata', () {
      final trip = makeTrip('d5', destination: lisbona);

      expect(tripDestinationName(trip, houseName: ''), 'Lisbona');
    });
  });

  group('nightsBetween', () {
    test('conta i giorni di calendario', () {
      expect(
        nightsBetween(DateTime(2026, 10, 28, 9), DateTime(2026, 10, 31, 8)),
        3,
      );
    });

    test('null se manca una data', () {
      expect(nightsBetween(null, DateTime(2026, 10, 31)), isNull);
      expect(nightsBetween(DateTime(2026, 10, 28), null), isNull);
    });
  });

  group('stampFor', () {
    final now = DateTime(2026, 10, 19, 10);

    test('partenza tra 9 giorni: daysLeft con giorni', () {
      final trip = makeTrip('s1', departure: DateTime(2026, 10, 28, 9));

      final stamp = stampFor(trip, now);

      expect(stamp.kind, StampKind.daysLeft);
      expect(stamp.days, 9);
    });

    test('partenza oggi alle 18: today', () {
      final trip = makeTrip('s2', departure: DateTime(2026, 10, 19, 18));

      expect(stampFor(trip, now).kind, StampKind.today);
    });

    test('viaggio in corso: traveling', () {
      final trip = makeTrip(
        's3',
        departure: DateTime(2026, 10, 15, 9),
        returnAt: DateTime(2026, 10, 25, 9),
      );

      expect(stampFor(trip, now).kind, StampKind.traveling);
    });

    test('senza partenza: noDate', () {
      final trip = makeTrip('s4');

      expect(stampFor(trip, now).kind, StampKind.noDate);
    });
  });

  group('ctaFor', () {
    test('senza oggetti: prepare', () {
      expect(ctaFor(makeTrip('c1')), PostcardCta.prepare);
    });

    test('tutti spuntati: ready', () {
      final trip = makeTrip(
        'c2',
        items: [makeItem('a', checked: true), makeItem('b', checked: true)],
      );

      expect(ctaFor(trip), PostcardCta.ready);
    });

    test('alcuni non spuntati: continuePacking', () {
      final trip = makeTrip(
        'c3',
        items: [makeItem('a', checked: true), makeItem('b')],
      );

      expect(ctaFor(trip), PostcardCta.continuePacking);
    });

    test('in corso senza oggetti: prepare', () {
      final now = DateTime.now();
      final trip = makeTrip(
        'c4',
        departure: now.subtract(const Duration(days: 1)),
        returnAt: now.add(const Duration(days: 1)),
      );

      expect(ctaFor(trip), PostcardCta.prepare);
    });
  });

  group('upcomingTrips', () {
    test(
      'ordina in corso con ritorno, in corso senza ritorno, futuri, senza date',
      () {
        final real = DateTime.now();
        final futuro25 = makeTrip(
          'futuro25',
          departure: real.add(const Duration(days: 25)),
          createdAt: DateTime(2026, 1, 1),
        );
        final senzaDate = makeTrip(
          'senzaDate',
          createdAt: DateTime(2026, 2, 1),
        );
        final inCorsoRitorno = makeTrip(
          'inCorsoRitorno',
          departure: real.subtract(const Duration(days: 1)),
          returnAt: real.add(const Duration(days: 2)),
        );
        final futuro10 = makeTrip(
          'futuro10',
          departure: real.add(const Duration(days: 10)),
        );
        final inCorsoSenzaRitorno = makeTrip(
          'inCorsoSenzaRitorno',
          departure: real.subtract(const Duration(days: 1)),
          createdAt: DateTime(2026, 3, 1),
        );
        final passato = makeTrip(
          'passato',
          departure: real.subtract(const Duration(days: 10)),
          returnAt: real.subtract(const Duration(days: 5)),
        );

        final result = upcomingTrips([
          futuro25,
          senzaDate,
          inCorsoRitorno,
          futuro10,
          inCorsoSenzaRitorno,
          passato,
        ]);

        expect(result.map((t) => t.id).toList(), [
          'inCorsoRitorno',
          'inCorsoSenzaRitorno',
          'futuro10',
          'futuro25',
          'senzaDate',
        ]);
      },
    );

    test('stessa chiave: ordine per id, indipendente dall ingresso', () {
      final partenza = DateTime.now().add(const Duration(days: 30));
      final result = upcomingTrips([
        makeTrip('b', departure: partenza),
        makeTrip('a', departure: partenza),
      ]);

      expect(result.map((t) => t.id).toList(), ['a', 'b']);
    });
  });

  group('pastTrips', () {
    test('solo completati, dal più recente', () {
      final real = DateTime.now();
      final vecchio = makeTrip(
        'vecchio',
        departure: real.subtract(const Duration(days: 40)),
        returnAt: real.subtract(const Duration(days: 35)),
      );
      final recente = makeTrip(
        'recente',
        departure: real.subtract(const Duration(days: 10)),
        returnAt: real.subtract(const Duration(days: 5)),
      );
      final futuro = makeTrip(
        'futuro',
        departure: real.add(const Duration(days: 10)),
      );

      final result = pastTrips([vecchio, futuro, recente]);

      expect(result.map((t) => t.id).toList(), ['recente', 'vecchio']);
    });

    test('stesso rientro: ordine per id, indipendente dall ingresso', () {
      final rientro = DateTime(2026, 9, 1);
      final result = pastTrips([
        makeTrip('b', departure: DateTime(2026, 8, 1), returnAt: rientro),
        makeTrip('a', departure: DateTime(2026, 8, 1), returnAt: rientro),
      ]);

      expect(result.map((t) => t.id).toList(), ['a', 'b']);
    });
  });

  group('savedTrips', () {
    test('solo salvati, per partenza decrescente', () {
      final anticipo = makeTrip(
        'anticipo',
        departure: DateTime(2026, 5, 1),
        saved: true,
      );
      final tardi = makeTrip(
        'tardi',
        departure: DateTime(2026, 12, 1),
        saved: true,
      );
      final nonSalvato = makeTrip(
        'nonSalvato',
        departure: DateTime(2026, 8, 1),
      );

      final result = savedTrips([anticipo, nonSalvato, tardi]);

      expect(result.map((t) => t.id).toList(), ['tardi', 'anticipo']);
    });

    test('stessa partenza: ordine per id, indipendente dall ingresso', () {
      final partenza = DateTime(2026, 8, 1);
      final result = savedTrips([
        makeTrip('b', departure: partenza, saved: true),
        makeTrip('a', departure: partenza, saved: true),
      ]);

      expect(result.map((t) => t.id).toList(), ['a', 'b']);
    });
  });

  group('groupByYear', () {
    test('anni decrescenti, ordine interno invariato', () {
      final a = makeTrip('a', departure: DateTime(2026, 3, 1));
      final b = makeTrip('b', departure: DateTime(2025, 7, 1));
      final c = makeTrip('c', departure: DateTime(2026, 1, 1));

      final result = groupByYear([a, b, c]);

      expect(result.map((e) => e.key).toList(), [2026, 2025]);
      expect(result[0].value.map((t) => t.id).toList(), ['a', 'c']);
      expect(result[1].value.map((t) => t.id).toList(), ['b']);
    });

    test('senza partenza usa l\'anno di createdAt', () {
      final senza = makeTrip('senza', createdAt: DateTime(2024, 6, 1));

      final result = groupByYear([senza]);

      expect(result.map((e) => e.key).toList(), [2024]);
    });
  });
}
