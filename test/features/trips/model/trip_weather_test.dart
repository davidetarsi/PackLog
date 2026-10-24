import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

final _today = DateTime(2026, 10, 20, 15, 30);

LocationSuggestionModel _place(
  String city, {
  double? lat = 38.7,
  double? lon,
}) => LocationSuggestionModel(
  placeId: 'p-$city',
  displayName: '$city, Portogallo',
  city: city,
  country: 'Portogallo',
  lat: lat,
  lon: lon ?? (lat == null ? null : -9.1),
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
  departureDateTime: departure,
  returnDateTime: returnAt,
  destinationLocation: destination,
  destinationHouseId: destinationHouseId,
  legs: legs,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripLeg _leg(
  String name,
  DateTime from,
  DateTime to, {
  double? lat = 38.8,
  String? houseId,
}) => TripLeg(
  id: 'leg-$name',
  locationDisplayName: '$name, Portogallo',
  from: from,
  to: to,
  lat: lat,
  lon: lat == null ? null : -9.4,
  country: lat == null ? null : 'Portogallo',
  houseId: houseId,
);

HouseModel _house(
  String id,
  String name, {
  LocationSuggestionModel? location,
}) => HouseModel(
  id: id,
  name: name,
  location: location,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripWeatherRequest _request(TripWeatherPlan plan) {
  expect(plan, isA<TripWeatherRequest>());
  return plan as TripWeatherRequest;
}

WeatherUnavailable _reason(TripWeatherPlan plan) {
  expect(plan, isA<TripWeatherNotPossible>());
  return (plan as TripWeatherNotPossible).reason;
}

void main() {
  group('planTripWeather', () {
    test('una meta: tutti i giorni, ritorno compreso', () {
      final plan = _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 30, 8),
            returnAt: DateTime(2026, 11, 4, 20),
            destination: _place('Lisbona'),
          ),
          houses: const [],
          today: _today,
        ),
      );
      expect(plan.stops, hasLength(1));
      expect(plan.stops.single.name, 'Lisbona');
      expect(plan.stops.single.days, 6);
      expect(plan.toJson(), {
        'trip': {
          'data_inizio': '2026-10-30',
          'tappe': [
            {
              'nome': 'Lisbona',
              'paese': 'Portogallo',
              'lat': 38.7,
              'lon': -9.1,
              'giorni': 6,
            },
          ],
        },
      });
    });

    test('a tappe: ogni giorno va dove si dorme, l\'ultimo all\'ultima', () {
      final plan = _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 30),
            returnAt: DateTime(2026, 11, 4),
            destination: _place('Lisbona'),
            legs: [
              _leg('Sintra', DateTime(2026, 11, 2), DateTime(2026, 11, 4)),
            ],
          ),
          houses: const [],
          today: _today,
        ),
      );
      expect(plan.stops.map((s) => (s.name, s.days)), [
        ('Lisbona', 3),
        ('Sintra', 3),
      ]);
      expect(plan.stops[1].from, DateTime(2026, 11, 2));
      expect(plan.stops[1].to, DateTime(2026, 11, 4));
    });

    test('in corso: parte da oggi', () {
      final plan = _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 18),
            returnAt: DateTime(2026, 10, 22),
            destination: _place('Lisbona'),
          ),
          houses: const [],
          today: _today,
        ),
      );
      expect(plan.start, DateTime(2026, 10, 20));
      expect(plan.stops.single.days, 3);
    });

    test('in corso: le tappe già passate spariscono', () {
      final plan = _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 15),
            returnAt: DateTime(2026, 10, 22),
            destination: _place('Lisbona'),
            legs: [
              _leg('Sintra', DateTime(2026, 10, 19), DateTime(2026, 10, 22)),
            ],
          ),
          houses: const [],
          today: _today,
        ),
      );
      expect(plan.stops.map((s) => s.name), ['Sintra']);
      expect(plan.stops.single.days, 3);
    });

    test('meta casa: coordinate e nome dalla casa', () {
      final house = _house(
        'h1',
        'Casa al mare',
        location: _place('Riccione', lat: 44.0, lon: 12.6),
      );
      final plan = _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 25),
            returnAt: DateTime(2026, 10, 26),
            destinationHouseId: 'h1',
            destination: LocationSuggestionModel(
              placeId: '',
              displayName: 'Casa al mare',
            ),
          ),
          houses: [house],
          today: _today,
        ),
      );
      final stop = plan.stops.single;
      expect(stop.name, 'Casa al mare');
      expect((stop.lat, stop.lon), (44.0, 12.6));
    });

    test('tappa casa senza coordinate nella tappa: dalla casa', () {
      final plan = _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 25),
            returnAt: DateTime(2026, 10, 28),
            destination: _place('Lisbona'),
            legs: [
              _leg(
                'Baita',
                DateTime(2026, 10, 27),
                DateTime(2026, 10, 28),
                lat: null,
                houseId: 'h2',
              ),
            ],
          ),
          houses: [
            _house(
              'h2',
              'Baita',
              location: _place('Courmayeur', lat: 45.8, lon: 6.97),
            ),
          ],
          today: _today,
        ),
      );
      expect(plan.stops.last.name, 'Baita');
      expect(plan.stops.last.lat, 45.8);
    });

    test('motivi per cui non si chiede', () {
      WeatherUnavailable reasonFor(TripModel trip) =>
          _reason(planTripWeather(trip, houses: const [], today: _today));

      expect(reasonFor(_trip()), WeatherUnavailable.noDates);
      expect(
        reasonFor(
          _trip(
            departure: DateTime(2026, 10, 1),
            returnAt: DateTime(2026, 10, 19),
            destination: _place('Lisbona'),
          ),
        ),
        WeatherUnavailable.past,
      );
      expect(
        reasonFor(
          _trip(
            departure: DateTime(2028, 12, 1),
            returnAt: DateTime(2028, 12, 3),
            destination: _place('Lisbona'),
          ),
        ),
        WeatherUnavailable.tooFar,
      );
      expect(
        reasonFor(
          _trip(
            departure: DateTime(2026, 11, 1),
            returnAt: DateTime(2027, 1, 1),
            destination: _place('Lisbona'),
          ),
        ),
        WeatherUnavailable.tooLong,
      );
      expect(
        reasonFor(
          _trip(
            departure: DateTime(2026, 11, 1),
            returnAt: DateTime(2026, 11, 3),
            destination: _place('Lisbona', lat: null),
          ),
        ),
        WeatherUnavailable.missingPlace,
      );
      expect(
        reasonFor(
          _trip(
            departure: DateTime(2026, 11, 1),
            returnAt: DateTime(2026, 11, 20),
            destination: _place('Lisbona'),
            legs: [
              for (var i = 0; i < 8; i++)
                _leg(
                  'T$i',
                  DateTime(2026, 11, 3 + i * 2),
                  DateTime(2026, 11, 5 + i * 2),
                ),
            ],
          ),
        ),
        WeatherUnavailable.tooManyStops,
      );
    });

    test('la chiave della tappa non entra nella firma', () {
      final request = TripWeatherRequest([
        WeatherStopRequest(
          stopKey: 'leg-x',
          name: 'Lisbona',
          country: 'Portogallo',
          lat: 38.7,
          lon: -9.1,
          from: DateTime(2026, 10, 30),
          days: 6,
        ),
      ]);
      expect(
        request.signature,
        '{"trip":{"data_inizio":"2026-10-30","tappe":[{"nome":"Lisbona",'
        '"paese":"Portogallo","lat":38.7,"lon":-9.1,"giorni":6}]}}',
      );
    });

    test(
      'chiavi: meta main, ogni tappa la sua, stesso luogo stessa chiave',
      () {
        final plan = _request(
          planTripWeather(
            _trip(
              departure: DateTime(2026, 10, 30),
              returnAt: DateTime(2026, 11, 6),
              destination: _place('Lisbona'),
              legs: [
                TripLeg(
                  id: 'leg1',
                  locationDisplayName: 'Sintra, Portogallo',
                  from: DateTime(2026, 11, 2),
                  to: DateTime(2026, 11, 3),
                  lat: 38.8,
                  lon: -9.4,
                ),
                TripLeg(
                  id: 'leg2',
                  locationDisplayName: 'Lisbona, Portogallo',
                  from: DateTime(2026, 11, 4),
                  to: DateTime(2026, 11, 6),
                  lat: 38.7,
                  lon: -9.1,
                ),
              ],
            ),
            houses: const [],
            today: _today,
          ),
        );
        expect(plan.stops.map((s) => s.stopKey), [
          kMainStopKey,
          'leg1',
          kMainStopKey,
        ]);
      },
    );

    test('la firma cambia con le date', () {
      TripWeatherRequest plan(DateTime returnAt) => _request(
        planTripWeather(
          _trip(
            departure: DateTime(2026, 10, 30),
            returnAt: returnAt,
            destination: _place('Lisbona'),
          ),
          houses: const [],
          today: _today,
        ),
      );
      expect(
        plan(DateTime(2026, 11, 4)).signature,
        plan(DateTime(2026, 11, 4, 23)).signature,
      );
      expect(
        plan(DateTime(2026, 11, 4)).signature,
        isNot(plan(DateTime(2026, 11, 5)).signature),
      );
    });
  });

  group('TripWeather', () {
    final request = TripWeatherRequest([
      WeatherStopRequest(
        stopKey: kMainStopKey,
        name: 'Lisbona',
        country: 'Portogallo',
        lat: 38.7,
        lon: -9.1,
        from: DateTime(2026, 10, 30),
        days: 3,
      ),
      WeatherStopRequest(
        stopKey: 'leg1',
        name: 'Sintra',
        country: 'Portogallo',
        lat: 38.8,
        lon: -9.4,
        from: DateTime(2026, 11, 2),
        days: 3,
      ),
    ]);

    Map<String, dynamic> meteo(String fonte, double min, double max) => {
      'fonte': fonte,
      'temp_min_media': min,
      'temp_max_media': max,
      'giorni_di_pioggia': 1.4,
      'pioggia_totale_mm': 6.2,
      'vento_max_kmh': 41.0,
      'uv_max': 5.5,
      if (fonte != 'previsione') 'anni_mediati': 5,
    };

    final response = {
      'geo': {
        'per_tappa': [
          {'destinazione': 'Lisbona', 'meteo': meteo('previsione', 15, 22)},
          {'destinazione': 'Sintra', 'meteo': meteo('storico 5 anni', 13, 19)},
        ],
      },
      'meteo': {'fonte': 'previsione + storico 5 anni'},
    };

    test('legge la risposta per tappa', () {
      final weather = TripWeather.fromResponse(
        response,
        request: request,
        fetchedAt: DateTime(2026, 10, 20, 9, 30),
      );
      expect(weather.stops.map((s) => s.source), [
        WeatherSource.forecast,
        WeatherSource.climate,
      ]);
      expect(weather.source, isNull);
      expect(weather.years, 5);
      final sintra = weather.stops[1];
      expect(sintra.name, 'Sintra');
      expect((sintra.tempMin, sintra.tempMax), (13.0, 19.0));
      expect(sintra.from, DateTime(2026, 11, 2));
      expect(sintra.days, 3);
      expect(weather.signature, request.signature);
    });

    test('legge i giorni e le fasce del dettaglio', () {
      final conDettaglio =
          jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
      ((conDettaglio['geo'] as Map)['per_tappa'] as List)[0]['dettaglio'] = [
        {
          'data': '2026-10-30',
          'codice': 61,
          'temp_min': 14.2,
          'temp_max': 21.6,
          'prob_pioggia': 80,
          'pioggia_mm': 2.5,
          'vento_max_kmh': 33.0,
          'uv_max': 5.5,
          'fasce': [
            for (var h = 0; h < 24; h += 4)
              {
                'da': h,
                'codice': h == 12 ? 61 : 1,
                'temp_media': 15.0 + h / 4,
                'prob_pioggia': h == 12 ? 80 : 10,
                'pioggia_mm': h == 12 ? 2.5 : 0,
                'vento_kmh': 12.0,
              },
          ],
        },
      ];
      final weather = TripWeather.fromResponse(
        conDettaglio,
        request: request,
        fetchedAt: DateTime(2026, 10, 20, 9, 30),
      );
      final lisbona = weather.stops.first;
      expect(lisbona.forecastDays, hasLength(1));
      final day = lisbona.forecastDays.single;
      expect(day.date, DateTime(2026, 10, 30));
      expect(day.rainProbability, 80);
      expect(day.bands.map((b) => (b.startHour, b.endHour)).last, (20, 24));
      expect(day.bands[3].code, 61);
      expect(day.bands[3].temp, 18.0);
      // Sintra non ha il dettaglio: non si apre.
      expect(weather.stops[1].forecastDays, isEmpty);

      final back = TripWeather.fromJson(
        jsonDecode(jsonEncode(weather.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), weather.toJson());
    });

    test('tappe diverse dalla richiesta: errore', () {
      expect(
        () => TripWeather.fromResponse(
          {
            'geo': {
              'per_tappa': [(response['geo']! as Map)['per_tappa'][0]],
            },
          },
          request: request,
          fetchedAt: DateTime(2026, 10, 20),
        ),
        throwsFormatException,
      );
    });

    test('va e torna dalla cache uguale', () {
      final weather = TripWeather.fromResponse(
        response,
        request: request,
        fetchedAt: DateTime(2026, 10, 20, 9, 30),
      );
      final back = TripWeather.fromJson(
        jsonDecode(jsonEncode(weather.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), weather.toJson());
      expect(back.fetchedAt, DateTime(2026, 10, 20, 9, 30));
    });

    test('fresco per 24 ore', () {
      final weather = TripWeather(
        signature: 's',
        fetchedAt: DateTime(2026, 10, 20, 9, 30),
        stops: const [],
      );
      expect(weather.isFresh(DateTime(2026, 10, 21, 9, 29)), isTrue);
      expect(weather.isFresh(DateTime(2026, 10, 21, 9, 30)), isFalse);
    });
  });
}
