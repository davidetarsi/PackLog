import '../../kits/model/kit_model.dart';
import '../../luggages/model/luggage_model.dart';
import 'ai_packing.dart';
import 'trip_weather.dart';

/// Lunghezza massima della descrizione del bagaglio (vedi `_kMaxText` lato
/// funzione).
const _kMaxBagText = 80;

/// Copie massime di un oggetto del kit: il massimo che la funzione accetta.
const _kMaxCopie = 99;

/// Una tappa del foglio della valigia AI: una per chiave, con i giorni di
/// tutti i suoi periodi.
class AiStop {
  const AiStop({
    required this.key,
    required this.name,
    required this.days,
    this.houseId,
  });

  final String key;
  final String name;
  final int days;

  /// La casa dell'utente dove si dorme in questa tappa, se c'è.
  final String? houseId;
}

/// Le tappe del foglio, una per chiave, nell'ordine della prima comparsa. Un
/// luogo spezzato in due periodi è una tappa sola, con i giorni sommati.
List<AiStop> aiStopsOf(TripWeatherRequest plan) {
  final byKey = <String, ({String name, int days, String? houseId})>{};
  for (final stop in plan.stops) {
    final previous = byKey[stop.stopKey];
    byKey[stop.stopKey] = (
      name: previous?.name ?? stop.name,
      days: (previous?.days ?? 0) + stop.days,
      houseId: previous?.houseId ?? stop.houseId,
    );
  }
  return [
    for (final entry in byKey.entries)
      AiStop(
        key: entry.key,
        name: entry.value.name,
        days: entry.value.days,
        houseId: entry.value.houseId,
      ),
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
/// [kits] sono i kit della casa scelta (campo `kit` solo se ce ne sono).
/// [language] è la lingua dell'app: motivi e avvisi tornano in quella (le
/// lingue diverse dall'italiano diventano inglese, come l'app).
Map<String, dynamic> packTripBody({
  required TripWeatherRequest plan,
  required AiPackingSetup setup,
  required String houseId,
  required String language,
  LuggageModel? luggage,
  List<String> transports = const [],
  List<KitModel> kits = const [],
}) {
  final stops = aiStopsOf(plan);
  final bagaglio = luggageDescription(luggage);
  final trip = <String, dynamic>{
    'data_inizio': isoDay(plan.start),
    if (bagaglio != null) 'bagaglio': bagaglio,
    if (transports.isNotEmpty) 'mezzi': transports,
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
  return {
    'house_id': houseId,
    'lang': language == 'it' ? 'it' : 'en',
    // Questa app mostra i posti: con la casa vuota la valigia è fatta di soli
    // posti. Senza, la funzione risponde 422 "Wardrobe is empty" (build vecchie).
    'posti': true,
    'trip': trip,
    // I kit della casa: la funzione decide quali entrano e risponde con `kit`.
    if (kits.isNotEmpty) 'kit': [for (final kit in kits) _kit(kit)],
  };
}

Map<String, dynamic> _kit(KitModel kit) => {
  'id': kit.id,
  'attivita': kit.activities,
  'mezzi': kit.transports,
  'oggetti': [
    for (final row in kit.items)
      {
        'item_id': row.itemId,
        'copie': row.copies > _kMaxCopie ? _kMaxCopie : row.copies,
      },
  ],
};

Map<String, dynamic> _place(WeatherStopRequest stop) => {
  'nome': stop.name,
  if (stop.country != null) 'paese': stop.country,
  'lat': stop.lat,
  'lon': stop.lon,
};

/// Attività e alloggio come id del catalogo (senza doppioni, nell'ordine delle
/// risposte): la funzione li traduce nei testi del generatore. Lavatrice.
Map<String, dynamic> _answerFields(AiStopAnswers? answers) {
  final ids = {...?answers?.activities}.toList();
  final stay = answers?.stay;
  return {
    'attivita': ids,
    if (stay != null) 'alloggio': stay,
    'lavatrice': answers?.washer ?? false,
  };
}
