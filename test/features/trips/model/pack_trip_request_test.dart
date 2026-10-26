import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/pack_trip_request.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';

WeatherStopRequest _stop(
  String key,
  String name,
  DateTime from,
  int days, {
  double lat = 38.7,
  double lon = -9.1,
}) => WeatherStopRequest(
  stopKey: key,
  name: name,
  country: 'Portogallo',
  lat: lat,
  lon: lon,
  from: from,
  days: days,
);

final _onePlacePlan = TripWeatherRequest([
  _stop(kMainStopKey, 'Lisbona', DateTime(2026, 10, 30), 6),
]);

final _twoPlacesPlan = TripWeatherRequest([
  _stop(kMainStopKey, 'Lisbona', DateTime(2026, 10, 30), 3),
  _stop('leg1', 'Sintra', DateTime(2026, 11, 2), 3, lat: 38.8, lon: -9.4),
]);

// A, B, di nuovo A: il luogo A è una tappa sola del foglio.
final _abaPlan = TripWeatherRequest([
  _stop(kMainStopKey, 'Lisbona', DateTime(2026, 10, 30), 2),
  _stop('leg1', 'Sintra', DateTime(2026, 11, 1), 2, lat: 38.8, lon: -9.4),
  _stop(kMainStopKey, 'Lisbona', DateTime(2026, 11, 3), 2),
]);

LuggageModel _luggage({
  LuggageSize size = LuggageSize.cabinBaggage,
  String name = 'Trolley',
  int? liters,
}) => LuggageModel(
  id: 'l1',
  name: name,
  sizeType: size,
  volumeLiters: liters,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final cabin = _luggage();

  group('packTripBody', () {
    test('una tappa sola: destinazione e campi di viaggio, mai tappe', () {
      final body = packTripBody(
        plan: _onePlacePlan,
        setup: AiPackingSetup(
          stops: {
            kMainStopKey: const AiStopAnswers(
              activities: [AiActivity.diving, AiActivity.sea],
              stay: AiStay.hotel,
              washer: true,
            ),
          },
        ),
        houseId: 'h1',
        luggage: cabin,
      );
      expect(body['house_id'], 'h1');
      final trip = body['trip'] as Map<String, dynamic>;
      expect(trip.containsKey('tappe'), isFalse);
      expect(trip['data_inizio'], '2026-10-30');
      expect(trip['giorni'], 6);
      expect(trip['destinazione'], {
        'nome': 'Lisbona',
        'paese': 'Portogallo',
        'lat': 38.7,
        'lon': -9.1,
      });
      expect(trip['attivita'], ['immersioni', 'mare']);
      expect(trip['alloggio'], 'hotel');
      expect(trip['lavatrice'], true);
      expect(trip['bagaglio'], 'trolley cabina');
    });

    test('una tappa senza risposte: niente alloggio, lavatrice spenta', () {
      final body = packTripBody(
        plan: _onePlacePlan,
        setup: const AiPackingSetup(),
        houseId: 'h1',
      );
      final trip = body['trip'] as Map<String, dynamic>;
      expect(trip.containsKey('alloggio'), isFalse);
      expect(trip.containsKey('bagaglio'), isFalse);
      expect(trip['attivita'], isEmpty);
      expect(trip['lavatrice'], false);
    });

    test('due tappe: risposte per tappa', () {
      final body = packTripBody(
        plan: _twoPlacesPlan,
        setup: const AiPackingSetup(
          stops: {
            kMainStopKey: AiStopAnswers(
              activities: [AiActivity.sea],
              stay: AiStay.hotel,
              washer: false,
            ),
            'leg1': AiStopAnswers(
              activities: [AiActivity.city],
              stay: AiStay.apartment,
              washer: true,
            ),
          },
        ),
        houseId: 'h1',
        luggage: cabin,
      );
      final trip = body['trip'] as Map<String, dynamic>;
      expect(trip['data_inizio'], '2026-10-30');
      expect(trip.containsKey('destinazione'), isFalse);
      expect(trip.containsKey('giorni'), isFalse);
      expect(trip.containsKey('alloggio'), isFalse);
      expect(trip['bagaglio'], 'trolley cabina');
      final tappe = trip['tappe'] as List;
      expect(tappe, hasLength(2));
      expect(tappe[0], {
        'nome': 'Lisbona',
        'paese': 'Portogallo',
        'lat': 38.7,
        'lon': -9.1,
        'giorni': 3,
        'attivita': ['mare'],
        'alloggio': 'hotel',
        'lavatrice': false,
      });
      expect(tappe[1]['attivita'], ['visite in citta']);
      expect(tappe[1]['alloggio'], 'appartamento');
      expect(tappe[1]['lavatrice'], true);
    });

    test('stesso luogo in due periodi: una voce per periodo, con la sua '
        'risposta', () {
      final body = packTripBody(
        plan: _abaPlan,
        setup: const AiPackingSetup(
          stops: {
            kMainStopKey: AiStopAnswers(
              activities: [AiActivity.city],
              stay: AiStay.hotel,
            ),
          },
        ),
        houseId: 'h1',
      );
      final tappe = (body['trip'] as Map<String, dynamic>)['tappe'] as List;
      expect(tappe.map((t) => (t as Map)['giorni']), [2, 2, 2]);
      expect(tappe[2]['attivita'], ['visite in citta']);
      expect(tappe[2]['alloggio'], 'hotel');
    });

    test('la chiave di una tappa sola resta la meta, non una tappa', () {
      expect(aiStopsOf(_onePlacePlan).map((s) => s.key), [kMainStopKey]);
    });

    test('attivita senza doppioni, nell\'ordine delle risposte', () {
      final body = packTripBody(
        plan: _onePlacePlan,
        setup: const AiPackingSetup(
          stops: {
            kMainStopKey: AiStopAnswers(
              activities: [
                AiActivity.diving,
                AiActivity.sea,
                AiActivity.diving,
              ],
              stay: AiStay.hotel,
            ),
          },
        ),
        houseId: 'h1',
      );
      final trip = body['trip'] as Map<String, dynamic>;
      expect(trip['attivita'], ['immersioni', 'mare']);
    });
  });

  group('aiStopsOf', () {
    test('una voce per chiave, nell\'ordine di comparsa, giorni sommati', () {
      final stops = aiStopsOf(_abaPlan);
      expect(stops.map((s) => s.key), [kMainStopKey, 'leg1']);
      expect(stops.map((s) => s.name), ['Lisbona', 'Sintra']);
      expect(stops.map((s) => s.days), [4, 2]);
    });
  });

  group('luggageDescription', () {
    test('zaino: litri della taglia', () {
      expect(
        luggageDescription(_luggage(size: LuggageSize.smallBackpack)),
        'zaino da 20 litri',
      );
    });

    test('taglie standard in parole', () {
      expect(
        luggageDescription(_luggage(size: LuggageSize.cabinBaggage)),
        'trolley cabina',
      );
      expect(
        luggageDescription(_luggage(size: LuggageSize.holdBaggage)),
        'valigia grande',
      );
    });

    test('personalizzato: nome e litri, o solo nome', () {
      expect(
        luggageDescription(
          _luggage(size: LuggageSize.custom, name: 'Borsa rossa', liters: 35),
        ),
        'Borsa rossa da 35 litri',
      );
      expect(
        luggageDescription(
          _luggage(size: LuggageSize.custom, name: 'Borsa rossa'),
        ),
        'Borsa rossa',
      );
    });

    test('tagliato a 80 caratteri', () {
      final text = luggageDescription(
        _luggage(size: LuggageSize.custom, name: 'a' * 200),
      );
      expect(text, isNotNull);
      expect(text!.length, lessThanOrEqualTo(80));
    });

    test('senza bagaglio: null', () {
      expect(luggageDescription(null), isNull);
    });
  });
}
