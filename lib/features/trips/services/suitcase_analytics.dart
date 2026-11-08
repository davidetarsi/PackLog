import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../items/model/item_model.dart';
import '../../luggages/model/luggage_model.dart';
import '../model/ai_packing.dart';
import '../model/trip_model.dart';
import '../model/trip_weather.dart';
import 'adopted_proposal.dart';
import 'pack_trip_service.dart';

/// Funzioni pure per gli eventi della valigia AI: trasformano viaggio, meteo
/// e armadio in proprietà piatte (solo testo, numeri e liste) per
/// `CoreAnalyticsService`. Mai la destinazione, i nomi delle tappe o dei capi.

/// La fascia di una temperatura in °C. Le soglie seguono il generatore
/// (21 è la soglia dei capi estivi).
String tempBand(double celsius) {
  if (celsius < 5) return 'lt5';
  if (celsius < 15) return '5_15';
  if (celsius < 21) return '15_21';
  if (celsius < 26) return '21_26';
  return 'gte26';
}

/// Il contesto di un viaggio: le risposte del foglio della valigia AI (id di
/// catalogo), il bagaglio, i mezzi e, se il meteo c'è, le fasce di
/// temperatura e i giorni di pioggia.
Map<String, Object> tripContext(
  TripModel trip, {
  LuggageModel? luggage,
  TripWeather? weather,
}) {
  final stops = trip.aiSetup?.stops.values ?? const [];
  final context = <String, Object>{
    'activities': {for (final s in stops) ...s.activities}.toList()..sort(),
    'stays': {for (final s in stops) ?s.stay}.toList()..sort(),
    'washer': stops.any((s) => s.washer),
    if (luggage != null) 'luggage_size': luggage.sizeType.name,
    'transports': trip.transports,
  };
  if (weather == null) return context;

  final maxima = weather.stops.map((s) => s.tempMax).whereType<double>();
  final minima = weather.stops.map((s) => s.tempMin).whereType<double>();
  final rain = weather.stops.map((s) => s.rainDays).whereType<double>();
  if (maxima.isNotEmpty) {
    context['temp_max_band'] = tempBand(maxima.reduce((a, b) => a > b ? a : b));
  }
  if (minima.isNotEmpty) {
    context['temp_min_band'] = tempBand(minima.reduce((a, b) => a < b ? a : b));
  }
  if (rain.isNotEmpty) context['rain_days'] = rain.reduce((a, b) => a + b);
  if (maxima.isNotEmpty || minima.isNotEmpty) {
    context['weather_source'] = weather.source?.name ?? 'mixed';
  }
  return context;
}

/// Giorni di calendario da [now] alla partenza; null senza partenza,
/// negativo se è già passata.
int? daysToDeparture(DateTime? departure, DateTime now) {
  if (departure == null) return null;
  final from = DateTime.utc(now.year, now.month, now.day);
  final to = DateTime.utc(departure.year, departure.month, departure.day);
  return to.difference(from).inDays;
}

/// Quanto la valigia di un viaggio si allontana dalla proposta AI.
typedef SuitcaseDiff = ({
  int proposed,
  int kept,
  int removed,
  int added,
  int slotCopiesFilled,
  int quantityChanged,
  List<String> removedTypes,
  List<String> addedTypes,
  List<String> quantityUpTypes,
  List<String> quantityDownTypes,
});

/// Null se il viaggio non ha una proposta AI. La proposta è quella che la
/// pagina ha salvato adottandola ([adoptedQuantities], con [available] =
/// pezzi in casa se l'armadio è caricato); i tipi vengono da
/// [subCategoryById] o, se manca, dalla categoria del capo in valigia.
/// `slotCopiesFilled`: copie riempite nei posti non tolti (gli oggetti dei
/// posti sono anche fra gli `added`, perché un TripItem non sa da dove viene).
SuitcaseDiff? suitcaseDiff(
  TripModel trip,
  Map<String, String> subCategoryById, {
  Map<String, int?>? available,
}) {
  final result = trip.aiResult;
  if (result == null) return null;

  final proposal = adoptedQuantities(result, available: available);
  final packed = {for (final i in trip.items) i.id: i};
  String typeOf(String id) =>
      subCategoryById[id] ?? packed[id]?.category.name ?? 'unknown';

  var kept = 0, quantityChanged = 0;
  final removedTypes = <String>[];
  final up = <String>[];
  final down = <String>[];
  proposal.forEach((id, quantity) {
    final item = packed[id];
    if (item == null) {
      removedTypes.add(typeOf(id));
      return;
    }
    kept++;
    if (item.quantity > quantity) up.add(typeOf(id));
    if (item.quantity < quantity) down.add(typeOf(id));
    if (item.quantity != quantity) quantityChanged++;
  });
  final addedTypes = [
    for (final id in packed.keys)
      if (!proposal.containsKey(id)) typeOf(id),
  ];
  final slotCopiesFilled = (result.slots ?? const [])
      .where((s) => !s.removed)
      .fold<int>(0, (sum, s) => sum + (s.copies - s.remaining));

  return (
    proposed: proposal.length,
    kept: kept,
    removed: removedTypes.length,
    added: addedTypes.length,
    slotCopiesFilled: slotCopiesFilled,
    quantityChanged: quantityChanged,
    removedTypes: removedTypes..sort(),
    addedTypes: addedTypes..sort(),
    quantityUpTypes: up..sort(),
    quantityDownTypes: down..sort(),
  );
}

/// Vero se [a] e [b] dicono le stesse cose (le liste confrontate per valore).
bool sameSuitcaseDiff(SuitcaseDiff a, SuitcaseDiff b) =>
    a.proposed == b.proposed &&
    a.kept == b.kept &&
    a.removed == b.removed &&
    a.added == b.added &&
    a.slotCopiesFilled == b.slotCopiesFilled &&
    a.quantityChanged == b.quantityChanged &&
    listEquals(a.removedTypes, b.removedTypes) &&
    listEquals(a.addedTypes, b.addedTypes) &&
    listEquals(a.quantityUpTypes, b.quantityUpTypes) &&
    listEquals(a.quantityDownTypes, b.quantityDownTypes);

/// [d] con i nomi delle proprietà di `ai_suitcase_changed`.
Map<String, Object> suitcaseDiffProperties(SuitcaseDiff d) => {
  'proposed': d.proposed,
  'kept': d.kept,
  'removed': d.removed,
  'added': d.added,
  'added_from_slots': d.slotCopiesFilled,
  'quantity_changed': d.quantityChanged,
  'removed_types': d.removedTypes,
  'added_types': d.addedTypes,
  'quantity_up_types': d.quantityUpTypes,
  'quantity_down_types': d.quantityDownTypes,
};

/// id → sottocategoria della tassonomia, letta da `ai_metadata`. Restano
/// fuori gli oggetti senza scheda o con un valore vuoto o `N/A`.
Map<String, String> subCategoryByIdOf(List<ItemModel> items) {
  final types = <String, String>{};
  for (final item in items) {
    final raw = item.aiMetadata;
    if (raw == null || raw.isEmpty) continue;
    try {
      final json = jsonDecode(raw);
      final type = json is Map ? json['subCategory'] : null;
      if (type is String && type.trim().isNotEmpty && type != 'N/A') {
        types[item.id] = type;
      }
    } on FormatException {
      continue;
    }
  }
  return types;
}

/// Come è finito un tentativo di generare la valigia, per
/// `ai_suitcase_finished`.
String packOutcomeOf(Object? failure, {required bool cancelled}) {
  if (cancelled) return 'cancelled';
  return switch (failure) {
    null => 'ok',
    PackTripCreditsException() => 'credits',
    PackTripEmptyWardrobeException() => 'empty_wardrobe',
    PackTripWardrobeTooLargeException() => 'wardrobe_too_large',
    PackTripNetworkException() => 'network',
    _ => 'error',
  };
}

/// La famiglia di `ai_metadata.category` → chiave di [wardrobeStats].
const _wardrobeKeys = {
  'Upper Body': 'wardrobe_upper',
  'Lower Body': 'wardrobe_lower',
  'Full Body': 'wardrobe_full_body',
  'Outerwear': 'wardrobe_outerwear',
  'Shoes': 'wardrobe_shoes',
  'Accessory': 'wardrobe_accessory',
  'Essentials': 'wardrobe_essentials',
};

/// Com'è fatto l'armadio da cui parte la valigia: quanti oggetti, quanti con
/// la scheda dell'AI, quanti per famiglia. Tutte le chiavi ci sono sempre.
Map<String, Object> wardrobeStats(List<ItemModel> items) {
  final stats = <String, int>{
    'wardrobe_items': items.length,
    'wardrobe_with_metadata': 0,
    for (final key in _wardrobeKeys.values) key: 0,
    'wardrobe_other': 0,
  };
  for (final item in items) {
    final raw = item.aiMetadata;
    Object? category;
    if (raw != null && raw.isNotEmpty) {
      stats['wardrobe_with_metadata'] = stats['wardrobe_with_metadata']! + 1;
      try {
        final json = jsonDecode(raw);
        category = json is Map ? json['category'] : null;
      } on FormatException {
        category = null;
      }
    }
    final key = _wardrobeKeys[category] ?? 'wardrobe_other';
    stats[key] = stats[key]! + 1;
  }
  return stats;
}

/// Le risposte del foglio cambiate rispetto alla generazione precedente
/// (`activities`, `luggage`, `stays`, `washer`, in ordine alfabetico); vuoto
/// alla prima generazione.
List<String> setupChangedFields(AiPackingSetup? before, AiPackingSetup after) {
  if (before == null) return const [];
  Set<String> activities(AiPackingSetup s) => {
    for (final stop in s.stops.values) ...stop.activities,
  };
  Set<String> stays(AiPackingSetup s) => {
    for (final stop in s.stops.values) ?stop.stay,
  };
  bool washer(AiPackingSetup s) => s.stops.values.any((stop) => stop.washer);
  return [
    if (!setEquals(activities(before), activities(after))) 'activities',
    if (before.luggageId != after.luggageId) 'luggage',
    if (!setEquals(stays(before), stays(after))) 'stays',
    if (washer(before) != washer(after)) 'washer',
  ];
}
