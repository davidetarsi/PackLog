import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/trips/model/ai_availability.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

final _today = DateTime(2026, 10, 24, 9);

LocationSuggestionModel _place(String city, {double? lat, double? lon}) =>
    LocationSuggestionModel(
      placeId: 'p-$city',
      displayName: '$city, Islanda',
      city: city,
      country: 'Islanda',
      lat: lat,
      lon: lon,
    );

TripModel _trip({
  DateTime? departure,
  DateTime? returnAt,
  LocationSuggestionModel? destination,
  String? destinationHouseId,
  List<TripLeg> legs = const [],
}) => TripModel(
  id: 't1',
  name: 'Viaggio',
  departureDateTime: departure ?? DateTime(2026, 11, 3),
  returnDateTime: returnAt ?? DateTime(2026, 11, 8),
  destinationLocation:
      destination ?? _place('Reykjavik', lat: 64.1, lon: -21.9),
  destinationHouseId: destinationHouseId,
  legs: legs,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripLeg _leg(int index, DateTime from, {double lat = 60, double lon = 10}) =>
    TripLeg(
      id: 'leg-$index',
      locationDisplayName: 'Luogo $index, Islanda',
      from: from,
      to: from.add(const Duration(days: 1)),
      lat: lat,
      lon: lon,
      country: 'Islanda',
    );

HouseModel _house(String id, {bool primary = false, double? lat}) => HouseModel(
  id: id,
  name: 'Casa $id',
  isPrimary: primary,
  location: lat == null ? null : _place('Città $id', lat: lat, lon: 9.1),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AiUnavailable _unavailable(TripModel trip) {
  final availability = aiAvailabilityOf(trip, houses: const [], today: _today);
  expect(availability, isA<AiUnavailable>());
  return availability as AiUnavailable;
}

void main() {
  group('aiAvailabilityOf', () {
    test('un viaggio con coordinate e meno di 60 giorni è disponibile', () {
      final availability = aiAvailabilityOf(
        _trip(),
        houses: const [],
        today: _today,
      );

      expect(availability, isA<AiAvailable>());
      final plan = (availability as AiAvailable).plan;
      expect(plan.stops.single.name, 'Reykjavik');
    });

    test('senza coordinate: missingPlace con la sua chiave', () {
      final unavailable = _unavailable(_trip(destination: _place('Reykjavik')));

      expect(unavailable.reason, WeatherUnavailable.missingPlace);
      expect(unavailable.messageKey, 'trips.ai.unavailable.missingPlace');
    });

    test('viaggio già finito: past', () {
      final unavailable = _unavailable(
        _trip(
          departure: DateTime(2026, 10, 1),
          returnAt: DateTime(2026, 10, 5),
        ),
      );

      expect(unavailable.reason, WeatherUnavailable.past);
      expect(unavailable.messageKey, 'trips.ai.unavailable.past');
    });

    test('più di 60 giorni: tooLong', () {
      final unavailable = _unavailable(
        _trip(departure: DateTime(2026, 11, 1), returnAt: DateTime(2027, 1, 1)),
      );

      expect(unavailable.reason, WeatherUnavailable.tooLong);
      expect(unavailable.messageKey, 'trips.ai.unavailable.tooLong');
    });

    test('più di 8 tappe: tooManyStops', () {
      // Meta più otto legs, ognuno in un giorno suo: nove tappe.
      final legs = [
        for (var i = 1; i <= 8; i++)
          _leg(
            i,
            DateTime(2026, 11, 3).add(Duration(days: i)),
            lat: 40 + i.toDouble(),
          ),
      ];
      final unavailable = _unavailable(
        _trip(returnAt: DateTime(2026, 11, 12), legs: legs),
      );

      expect(unavailable.reason, WeatherUnavailable.tooManyStops);
      expect(unavailable.messageKey, 'trips.ai.unavailable.tooManyStops');
    });

    test('senza date: noDates', () {
      final unavailable = _unavailable(
        _trip().copyWith(departureDateTime: null, returnDateTime: null),
      );

      expect(unavailable.reason, WeatherUnavailable.noDates);
    });
  });

  group('proposedPackingHouse', () {
    test('senza case: null', () {
      expect(proposedPackingHouse(const [], _trip()), isNull);
    });

    test('la principale, se non è la meta del viaggio', () {
      final houses = [_house('a'), _house('b', primary: true)];

      expect(proposedPackingHouse(houses, _trip())?.id, 'b');
    });

    test('se la principale è la meta, la prima altra casa', () {
      final houses = [_house('a'), _house('b', primary: true)];
      final trip = _trip(destinationHouseId: 'b');

      expect(proposedPackingHouse(houses, trip)?.id, 'a');
    });

    test('se la principale è la meta e non c è altra casa, resta lei', () {
      final houses = [_house('b', primary: true)];
      final trip = _trip(destinationHouseId: 'b');

      expect(proposedPackingHouse(houses, trip)?.id, 'b');
    });
  });
}
