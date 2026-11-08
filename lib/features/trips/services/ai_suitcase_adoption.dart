import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../items/model/item_model.dart';
import '../../luggages/model/luggage_model.dart';
import '../model/ai_packing.dart';
import '../model/trip_model.dart';

/// Chiave di `SharedPreferences` che ricorda se `first_suitcase_generated`
/// è già partito.
const _firstSuitcaseLoggedKey = 'first_suitcase_logged';

/// Il viaggio con la proposta adottata: oggetti e bagaglio, [setup] e
/// risultato. Il "da comprare" dei posti passa ai posti dello stesso tipo
/// della valigia precedente. Un oggetto non più in casa viene saltato. Con
/// [houseItems] null (gli oggetti della casa non si leggono) la proposta si
/// salva lo stesso, con oggetti e bagagli del viaggio com'erano.
TripModel adoptedTrip({
  required TripModel trip,
  required AiPackingResult proposal,
  required AiPackingSetup setup,
  LuggageModel? luggage,
  List<ItemModel>? houseItems,
}) {
  final result = carryKitCounted(
    trip.aiResult,
    carryToBuy(trip.aiResult, proposal),
  );
  final proposed = houseItems == null
      ? null
      : proposedItems(result, houseItems);
  return trip.copyWith(
    items: proposed?.values.toList() ?? trip.items,
    luggages: luggage == null || proposed == null ? trip.luggages : [luggage],
    aiSetup: setup,
    aiResult: result,
    updatedAt: DateTime.now(),
  );
}

/// I capi della proposta, con nome e categoria dell'oggetto di casa. Un
/// oggetto non più in casa non entra; la quantità sta tra 1 e i pezzi
/// salvati (senza quantità salvata, 1).
Map<String, TripItem> proposedItems(
  AiPackingResult result,
  List<ItemModel> houseItems,
) {
  final byId = {for (final item in houseItems) item.id: item};
  final items = <String, TripItem>{};
  for (final proposed in result.proposal) {
    final item = byId[proposed.itemId];
    if (item == null) continue;
    final available = item.quantity ?? 1;
    final cap = available < 1 ? 1 : available;
    final quantity = proposed.quantity < 1
        ? 1
        : (proposed.quantity > cap ? cap : proposed.quantity);
    items[item.id] = TripItem(
      id: item.id,
      name: item.name,
      category: item.category,
      quantity: quantity,
      originHouseId: result.houseId,
    );
  }
  // Gli oggetti dei kit entrati da soli: se l'oggetto c'è già vale il
  // massimo delle copie (mai la somma), sempre entro i pezzi in casa. Un
  // oggetto non più in casa si salta.
  for (final added in result.kitAdded) {
    final item = byId[added.itemId];
    if (item == null) continue;
    final available = item.quantity ?? 1;
    final cap = available < 1 ? 1 : available;
    final wanted = added.copies < 1 ? 1 : added.copies;
    final current = items[item.id]?.quantity ?? 0;
    final quantity = (wanted > current ? wanted : current).clamp(1, cap);
    items[item.id] = TripItem(
      id: item.id,
      name: item.name,
      category: item.category,
      quantity: quantity,
      originHouseId: result.houseId,
    );
  }
  return items;
}

/// "Islanda e Olanda", "Islanda, Olanda e Francia".
String joinStopNames(List<String> names) {
  if (names.length <= 1) return names.join();
  return 'trips.pack.ai.stops_join'.tr(
    args: [names.sublist(0, names.length - 1).join(', '), names.last],
  );
}

/// `first_suitcase_generated`: una volta sola per dispositivo (flag in
/// SharedPreferences, non per account), alla prima valigia con i posti
/// salvata. La retention a 1 e 7 giorni si legge in Amplitude partendo da
/// questo evento.
Future<void> logFirstSuitcase(
  AppAnalyticsService analytics,
  AiPackingResult result,
  int tripItems, {
  required bool fromFirstRun,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_firstSuitcaseLoggedKey) ?? false) return;
  await prefs.setBool(_firstSuitcaseLoggedKey, true);
  final slots = result.slots ?? const <AiSlot>[];
  // Non si aspetta: un errore dell'analytics non deve fermare la navigazione.
  unawaited(
    analytics.logEvent(
      'first_suitcase_generated',
      properties: {
        'slots_important': slots
            .where((s) => s.level == AiSlotLevel.important)
            .length,
        'slots_proposed': slots
            .where((s) => s.level == AiSlotLevel.useful)
            .length,
        'slots_total': slots.length,
        'trip_items': tripItems,
        'from_first_run': fromFirstRun,
      },
    ),
  );
}

/// `kit_auto_added`: i kit entrati da soli nella valigia salvata (quanti
/// kit e quanti oggetti), solo se ce n'è stato qualcuno.
void logKitAutoAdded(AppAnalyticsService analytics, AiPackingResult result) {
  if (result.kitAdded.isEmpty) return;
  unawaited(
    analytics.logEvent(
      'kit_auto_added',
      properties: {
        'kits': {for (final a in result.kitAdded) a.kitId}.length,
        'items': result.kitAdded.length,
      },
    ),
  );
}
