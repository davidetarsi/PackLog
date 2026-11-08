import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/services/suitcase_analytics.dart';

TripModel _trip() => TripModel(
  id: 't1',
  name: 'Lisbona',
  transports: const ['plane'],
  aiSetup: const AiPackingSetup(
    houseId: 'h1',
    luggageId: 'l1',
    stops: {
      'a': AiStopAnswers(
        activities: ['hiking', 'beach'],
        stay: 'apartment',
        washer: false,
      ),
      'b': AiStopAnswers(activities: ['beach'], washer: true),
    },
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

StopWeather _stop({double? tempMin, double? tempMax, double? rainDays}) =>
    StopWeather(
      name: 'tappa',
      from: DateTime(2026, 11, 10),
      to: DateTime(2026, 11, 12),
      source: WeatherSource.forecast,
      tempMin: tempMin,
      tempMax: tempMax,
      rainDays: rainDays,
    );

void main() {
  group('tempBand', () {
    test('soglie 5, 15, 21, 26', () {
      expect(tempBand(4.9), 'lt5');
      expect(tempBand(5), '5_15');
      expect(tempBand(20.9), '15_21');
      expect(tempBand(21), '21_26');
      expect(tempBand(26), 'gte26');
    });
  });

  group('tripContext', () {
    final weather = TripWeather(
      signature: 's',
      fetchedAt: DateTime(2026, 11, 8),
      stops: [
        _stop(tempMin: 12, tempMax: 23, rainDays: 2),
        _stop(tempMin: 8, tempMax: 19),
      ],
    );
    final luggage = LuggageModel(
      id: 'l1',
      name: 'Zaino',
      sizeType: LuggageSize.cabinBaggage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('risposte del foglio, bagaglio, mezzi e meteo', () {
      final context = tripContext(_trip(), luggage: luggage, weather: weather);
      expect(context, {
        'activities': ['beach', 'hiking'],
        'stays': ['apartment'],
        'washer': true,
        'luggage_size': 'cabinBaggage',
        'transports': ['plane'],
        'temp_max_band': '21_26',
        'temp_min_band': '5_15',
        'rain_days': 2,
        'weather_source': 'forecast',
      });
    });

    test('senza meteo niente chiavi di clima, il resto sì', () {
      final context = tripContext(_trip());
      expect(context.keys.where((k) => k.startsWith('temp_')), isEmpty);
      expect(context.containsKey('rain_days'), isFalse);
      expect(context.containsKey('weather_source'), isFalse);
      expect(context.containsKey('luggage_size'), isFalse);
      expect(context['activities'], ['beach', 'hiking']);
    });

    test('meteo senza temperature: niente fasce', () {
      final context = tripContext(
        _trip(),
        weather: TripWeather(
          signature: 's',
          fetchedAt: DateTime(2026, 11, 8),
          stops: [_stop()],
        ),
      );
      expect(context.keys.where((k) => k.startsWith('temp_')), isEmpty);
      expect(context.containsKey('rain_days'), isFalse);
    });

    test('viaggio senza foglio: liste vuote, lavatrice falsa', () {
      final trip = _trip().copyWith(aiSetup: null);
      final context = tripContext(trip);
      expect(context['activities'], isEmpty);
      expect(context['stays'], isEmpty);
      expect(context['washer'], isFalse);
    });
  });

  group('daysToDeparture', () {
    test('giorni di calendario, null senza partenza, negativo nel passato', () {
      final now = DateTime(2026, 11, 8, 23);
      expect(daysToDeparture(DateTime(2026, 11, 18, 8), now), 10);
      expect(daysToDeparture(DateTime(2026, 11, 8, 6), now), 0);
      expect(daysToDeparture(DateTime(2026, 11, 6), now), -2);
      expect(daysToDeparture(null, now), isNull);
    });
  });
}
