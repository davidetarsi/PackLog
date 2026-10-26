import '../../luggages/model/luggage_model.dart';
import 'ai_packing.dart';
import 'trip_weather.dart';

/// Lunghezza massima della descrizione del bagaglio (vedi `_kMaxText` lato
/// funzione).
const _kMaxBagText = 80;

/// Una tappa del foglio della valigia AI: una per chiave, con i giorni di
/// tutti i suoi periodi.
class AiStop {
  const AiStop({required this.key, required this.name, required this.days});

  final String key;
  final String name;
  final int days;
}

/// Le tappe del foglio, una per chiave, nell'ordine della prima comparsa. Un
/// luogo spezzato in due periodi è una tappa sola, con i giorni sommati.
List<AiStop> aiStopsOf(TripWeatherRequest plan) {
  final byKey = <String, ({String name, int days})>{};
  for (final stop in plan.stops) {
    final previous = byKey[stop.stopKey];
    byKey[stop.stopKey] = (
      name: previous?.name ?? stop.name,
      days: (previous?.days ?? 0) + stop.days,
    );
  }
  return [
    for (final entry in byKey.entries)
      AiStop(key: entry.key, name: entry.value.name, days: entry.value.days),
  ];
}

/// Il bagaglio in una frase per la funzione: "zaino da 20 litri", "trolley
/// cabina", "valigia grande", "Borsa rossa da 35 litri". Null senza bagaglio.
String? luggageDescription(LuggageModel? luggage) {
  if (luggage == null) return null;
  final liters = luggage.effectiveVolumeLiters;
  final name = luggage.name.trim();
  final text = switch (luggage.sizeType) {
    LuggageSize.smallBackpack =>
      liters == null ? 'zaino' : 'zaino da $liters litri',
    LuggageSize.cabinBaggage => 'trolley cabina',
    LuggageSize.holdBaggage => 'valigia grande',
    LuggageSize.custom => liters == null ? name : '$name da $liters litri',
  };
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= _kMaxBagText
      ? trimmed
      : trimmed.substring(0, _kMaxBagText).trim();
}

/// Il corpo di `pack-trip` per il piano [plan] con le risposte [setup].
///
/// Un solo luogo nel piano: `destinazione` e i campi di viaggio. Più luoghi:
/// `tappe`, una voce per ogni periodo, con le risposte del suo luogo.
Map<String, dynamic> packTripBody({
  required TripWeatherRequest plan,
  required AiPackingSetup setup,
  required String houseId,
  LuggageModel? luggage,
}) {
  final stops = aiStopsOf(plan);
  final bagaglio = luggageDescription(luggage);
  final trip = <String, dynamic>{
    'data_inizio': isoDay(plan.start),
    if (bagaglio != null) 'bagaglio': bagaglio,
  };
  if (stops.length == 1) {
    trip['destinazione'] = _place(plan.stops.first);
    trip['giorni'] = stops.single.days;
    trip.addAll(_answerFields(setup.stops[stops.single.key]));
  } else {
    trip['tappe'] = [
      for (final stop in plan.stops)
        {
          ..._place(stop),
          'giorni': stop.days,
          ..._answerFields(setup.stops[stop.stopKey]),
        },
    ];
  }
  return {'house_id': houseId, 'trip': trip};
}

Map<String, dynamic> _place(WeatherStopRequest stop) => {
  'nome': stop.name,
  if (stop.country != null) 'paese': stop.country,
  'lat': stop.lat,
  'lon': stop.lon,
};

/// Attività (codici del generatore, senza doppioni, nell'ordine delle
/// risposte), alloggio se scelto, lavatrice.
Map<String, dynamic> _answerFields(AiStopAnswers? answers) {
  final codes = <String>{
    for (final activity in answers?.activities ?? const <AiActivity>[])
      ...activity.generatorCodes,
  };
  final stay = answers?.stay;
  return {
    'attivita': codes.toList(),
    if (stay != null) 'alloggio': stay.generatorText,
    'lavatrice': answers?.washer ?? false,
  };
}
