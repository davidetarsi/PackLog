import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_draft.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_postcard.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

DateTime d(int day) => DateTime(2026, 11, day);

final o29 = DateTime(2026, 10, 29);

DraftPlace lisbona() => DraftPlace.location(
  LocationSuggestionModel(
    placeId: 'lisbona',
    displayName: 'Lisbona, Portogallo',
    city: 'Lisbona',
    country: 'Portogallo',
    lat: 38.72,
    lon: -9.14,
  ),
);

DraftPlace porto() => DraftPlace.location(
  LocationSuggestionModel(
    placeId: 'porto',
    displayName: 'Porto, Portogallo',
    city: 'Porto',
    country: 'Portogallo',
    lat: 41.15,
    lon: -8.61,
  ),
);

DraftPlace sintra() => DraftPlace.location(
  LocationSuggestionModel(
    placeId: 'sintra',
    displayName: 'Sintra, Portogallo',
    lat: 38.79,
    lon: -9.39,
  ),
);

DraftPlace casaDiSintra() =>
    const DraftPlace.house(id: 'casa-sintra', name: 'Casa di Sintra');

void main() {
  group('TripDraft nome', () {
    test('segue la meta finché il nome non è stato cambiato a mano', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withDestination(porto());

      expect(draft.name, 'Porto');
      expect(draft.nameEdited, isFalse);
    });

    test('una meta nuova dopo un nome a mano non cambia il nome', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withName('Weekend di famiglia')
          .withDestination(porto());

      expect(draft.name, 'Weekend di famiglia');
      expect(draft.nameEdited, isTrue);
    });

    test('un nome svuotato torna a seguire la meta', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withName('   ')
          .withDestination(porto());

      expect(draft.nameEdited, isFalse);
      expect(draft.name, 'Porto');
    });
  });

  group('TripDraft catena delle date', () {
    test('addStop dopo le prime date parte dalla fine della prima tappa', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(sintra(), d(3));

      expect(draft.stopStart(0), o29);
      expect(draft.stopStart(1), d(1));
      expect(draft.returnDate, d(3));
    });

    test('le date scelte prima della meta restano quando arriva la meta', () {
      final draft = TripDraft.empty()
          .withFirstDates(o29, d(1))
          .withDestination(lisbona());

      expect(draft.stops.length, 1);
      expect(draft.stops.first.place.name, 'Lisbona, Portogallo');
      expect(draft.returnDate, d(1));
      expect(draft.hasDates, isTrue);
    });

    test('updateStop sposta solo l\'inizio della tappa successiva', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(sintra(), d(3))
          .addStop(porto(), d(6))
          .updateStop(1, end: d(4));

      expect(draft.stopStart(1), d(1));
      expect(draft.stops[0].end, d(1));
      expect(draft.stops[1].end, d(4));
      expect(draft.stopStart(2), d(4));
      expect(draft.returnDate, d(6));
    });

    test('removeStop a metà ricuce la catena e tiene la fine successiva', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(sintra(), d(3))
          .addStop(porto(), d(6))
          .removeStop(1);

      expect(draft.stops.length, 2);
      expect(draft.stopStart(1), d(1));
      expect(draft.stops[1].end, d(6));
      expect(draft.returnDate, d(6));
    });

    test('removeStop in fondo riporta il ritorno alla fine precedente', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(sintra(), d(3))
          .removeStop(1);

      expect(draft.stops.length, 1);
      expect(draft.returnDate, d(1));
    });

    test('stopsWithoutNights segnala la tappa scavalcata dalla prima', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(sintra(), d(3))
          .withFirstDates(o29, d(6));

      expect(draft.stopsWithoutNights, {1});
    });

    test(
      'le date sono solo giorno, il confronto è sui giorni di calendario',
      () {
        final draft = TripDraft.empty()
            .withDestination(lisbona())
            .withFirstDates(
              DateTime(2026, 10, 29, 18, 30),
              DateTime(2026, 11, 1, 9),
            );

        expect(draft.departure, o29);
        expect(draft.returnDate, d(1));
        expect(draft.stopsWithoutNights, isEmpty);
      },
    );
  });

  group('TripDraft salvataggio e uso', () {
    test('canSave è falso senza meta', () {
      final draft = TripDraft.empty().withFirstDates(o29, d(1));

      expect(draft.canSave, isFalse);
    });

    test('canSave è falso senza date', () {
      final draft = TripDraft.empty().withDestination(lisbona());

      expect(draft.canSave, isFalse);
    });

    test('canSave è falso con una tappa a zero notti', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(3))
          .addStop(sintra(), d(3));

      expect(draft.stopsWithoutNights, {1});
      expect(draft.canSave, isFalse);
    });

    test('canSave è vero con meta, date e tappe valide', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(sintra(), d(3));

      expect(draft.canSave, isTrue);
    });

    test('hasUserInput è falso con la bozza vuota', () {
      expect(TripDraft.empty().hasUserInput, isFalse);
    });

    test('hasUserInput è vero con la meta, anche con il nome proposto', () {
      // Il nome proposto da solo non conta, ma la meta sì (spec 10.7).
      final draft = TripDraft.empty().withDestination(lisbona());

      expect(draft.nameEdited, isFalse);
      expect(draft.hasUserInput, isTrue);
    });

    test('shortName coincide con tripDestinationName della cartolina', () {
      final now = DateTime(2026, 10, 20);
      for (final place in [lisbona(), sintra()]) {
        final trip = TripDraft.empty()
            .withDestination(place)
            .toTripModel(id: 'x', now: now);

        expect(place.shortName, tripDestinationName(trip));
      }
    });

    test('toTripModel con meta-luogo, tappa-casa e tappa-luogo', () {
      final now = DateTime(2026, 10, 20);
      final trip = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(1))
          .addStop(casaDiSintra(), d(3))
          .addStop(porto(), d(6))
          .toTripModel(id: 'trip-1', now: now);

      expect(trip.id, 'trip-1');
      expect(trip.name, 'Lisbona');
      expect(trip.destinationHouseId, isNull);
      expect(trip.destinationLocation!.displayName, 'Lisbona, Portogallo');
      expect(trip.destinationLocation!.lat, 38.72);
      expect(trip.destinationLocation!.lon, -9.14);
      expect(trip.departureDateTime, o29);
      expect(trip.returnDateTime, d(6));
      expect(trip.createdAt, now);
      expect(trip.updatedAt, now);
      expect(trip.items, isEmpty);
      expect(trip.luggages, isEmpty);

      expect(trip.legs.length, 2);

      final casa = trip.legs[0];
      expect(casa.id, isNotEmpty);
      expect(casa.locationDisplayName, 'Casa di Sintra');
      expect(casa.from, d(1));
      expect(casa.to, d(3));
      expect(casa.houseId, 'casa-sintra');
      expect(casa.lat, isNull);
      expect(casa.lon, isNull);

      final luogo = trip.legs[1];
      expect(luogo.id, isNotEmpty);
      expect(luogo.id, isNot(casa.id));
      expect(luogo.locationDisplayName, 'Porto, Portogallo');
      expect(luogo.from, d(3));
      expect(luogo.to, d(6));
      expect(luogo.houseId, isNull);
      expect(luogo.lat, 41.15);
      expect(luogo.lon, -8.61);
      expect(luogo.country, 'Portogallo');
    });

    test('toTripModel con meta-casa usa l\'id e il nome della casa', () {
      final trip = TripDraft.empty()
          .withDestination(casaDiSintra())
          .withFirstDates(o29, d(1))
          .toTripModel(id: 'trip-2', now: DateTime(2026, 10, 20));

      expect(trip.name, 'Casa di Sintra');
      expect(trip.destinationHouseId, 'casa-sintra');
      expect(trip.destinationLocation!.displayName, 'Casa di Sintra');
      expect(trip.destinationLocation!.lat, isNull);
      expect(trip.legs, isEmpty);
    });

    test('toTripModel con nome vuoto usa shortName della meta', () {
      final trip = TripDraft.empty()
          .withDestination(lisbona())
          .withName('')
          .withFirstDates(o29, d(1))
          .toTripModel(id: 'trip-3', now: DateTime(2026, 10, 20));

      expect(trip.name, 'Lisbona');
    });
  });

  group('TripDraft rimuovere la meta', () {
    test('toglie la meta e le sue tappe, e le date restano in attesa', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(3))
          .addStop(sintra(), d(5))
          .clearDestination();

      expect(draft.hasDestination, isFalse);
      expect(draft.stops, isEmpty);
      expect(draft.departure, o29);
      expect(draft.returnDate, d(3));
      expect(draft.canSave, isFalse);
    });

    test('il nome proposto si svuota, quello scritto a mano resta', () {
      final proposed = TripDraft.empty()
          .withDestination(lisbona())
          .clearDestination();
      expect(proposed.name, '');
      expect(proposed.nameEdited, isFalse);

      final edited = TripDraft.empty()
          .withDestination(lisbona())
          .withName('Weekend')
          .clearDestination();
      expect(edited.name, 'Weekend');
    });

    test('una nuova meta riprende le date rimaste in attesa', () {
      final draft = TripDraft.empty()
          .withDestination(lisbona())
          .withFirstDates(o29, d(3))
          .clearDestination()
          .withDestination(porto());

      expect(draft.name, 'Porto');
      expect(draft.stops.single.end, d(3));
      expect(draft.canSave, isTrue);
    });

    test('senza meta non cambia nulla', () {
      final draft = TripDraft.empty().withFirstDates(o29, d(1));

      final cleared = draft.clearDestination();

      expect(cleared.hasDestination, isFalse);
      expect(cleared.departure, o29);
      expect(cleared.returnDate, d(1));
    });
  });

  group('TripDraft.fromTrip', () {
    final milano = LocationSuggestionModel(
      placeId: 'm',
      displayName: 'Milano, Italia',
      city: 'Milano',
    );

    TripModel trip({
      List<TripLeg> legs = const [],
      String name = 'Milano',
      DateTime? departure,
      DateTime? ret,
      String? houseId,
    }) => TripModel(
      id: 't',
      name: name,
      departureDateTime: departure,
      returnDateTime: ret,
      destinationHouseId: houseId,
      destinationLocation: houseId == null ? milano : null,
      legs: legs,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('ricostruisce la catena: la meta finisce dove parte la tappa', () {
      final draft = TripDraft.fromTrip(
        trip(
          departure: DateTime(2026, 5, 1),
          ret: DateTime(2026, 5, 8),
          legs: [
            TripLeg(
              id: 'l',
              locationDisplayName: 'Como',
              from: DateTime(2026, 5, 4),
              to: DateTime(2026, 5, 8),
            ),
          ],
        ),
      );
      expect(draft.stops.length, 2);
      expect(draft.stops[0].end, DateTime(2026, 5, 4));
      expect(draft.stops[1].place.name, 'Como');
      expect(draft.returnDate, DateTime(2026, 5, 8));
      expect(draft.canSave, isTrue);
    });

    test('salvare senza cambiare nulla riporta le stesse date e tappe', () {
      final original = trip(
        departure: DateTime(2026, 5, 1),
        ret: DateTime(2026, 5, 8),
        legs: [
          TripLeg(
            id: 'l',
            locationDisplayName: 'Como',
            from: DateTime(2026, 5, 4),
            to: DateTime(2026, 5, 8),
          ),
        ],
      );
      final back = TripDraft.fromTrip(
        original,
      ).toTripModel(id: 't', now: DateTime(2026));
      expect(back.name, 'Milano');
      expect(back.departureDateTime, original.departureDateTime);
      expect(back.returnDateTime, original.returnDateTime);
      expect(back.legs.single.from, DateTime(2026, 5, 4));
      expect(back.legs.single.to, DateTime(2026, 5, 8));
      expect(back.destinationLocation, milano);
    });

    test('senza date (copia di Riusa): meta e nome, nessuna tappa', () {
      final draft = TripDraft.fromTrip(trip());
      expect(draft.hasDestination, isTrue);
      expect(draft.stops, isEmpty);
      expect(draft.hasDates, isFalse);
    });

    test('un nome diverso dalla meta conta come scritto a mano', () {
      expect(TripDraft.fromTrip(trip(name: 'Lavoro')).nameEdited, isTrue);
      expect(TripDraft.fromTrip(trip()).nameEdited, isFalse);
    });

    test('meta casa: usa il nome della casa', () {
      final draft = TripDraft.fromTrip(
        trip(houseId: 'h1', name: 'Baita'),
        houseName: 'Baita',
      );
      expect(draft.destination?.houseId, 'h1');
      expect(draft.destination?.name, 'Baita');
    });
  });
}
