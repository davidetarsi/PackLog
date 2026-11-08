import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../items/model/item_model.dart';
import '../../luggages/model/luggage_model.dart';
import '../model/ai_packing.dart';
import '../model/trip_model.dart';
import 'adopted_proposal.dart';

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

/// I capi della proposta (e dei kit entrati da soli), con nome e categoria
/// dell'oggetto di casa. Le quantità seguono [adoptedQuantities]: un oggetto
/// non più in casa non entra, i pezzi stanno tra 1 e quelli in casa.
Map<String, TripItem> proposedItems(
  AiPackingResult result,
  List<ItemModel> houseItems,
) {
  final byId = {for (final item in houseItems) item.id: item};
  final quantities = adoptedQuantities(
    result,
    available: {for (final item in houseItems) item.id: item.quantity},
  );
  return {
    for (final MapEntry(key: id, value: quantity) in quantities.entries)
      id: TripItem(
        id: id,
        name: byId[id]!.name,
        category: byId[id]!.category,
        quantity: quantity,
        originHouseId: result.houseId,
      ),
  };
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
  CoreAnalyticsService analytics,
  AiPackingResult result,
  int tripItems, {
  required bool fromFirstRun,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_firstSuitcaseLoggedKey) ?? false) return;
  await prefs.setBool(_firstSuitcaseLoggedKey, true);
  final slots = result.slots ?? const <AiSlot>[];
  analytics.trackFirstSuitcaseGenerated(
    slotsImportant: slots.where((s) => s.level == AiSlotLevel.important).length,
    slotsProposed: slots.where((s) => s.level == AiSlotLevel.useful).length,
    slotsTotal: slots.length,
    tripItems: tripItems,
    fromFirstRun: fromFirstRun,
  );
}

/// `kit_auto_added`: i kit entrati da soli nella valigia salvata (quanti
/// kit e quanti oggetti), solo se ce n'è stato qualcuno.
void logKitAutoAdded(CoreAnalyticsService analytics, AiPackingResult result) {
  if (result.kitAdded.isEmpty) return;
  analytics.trackKitAutoAdded(
    kits: {for (final a in result.kitAdded) a.kitId}.length,
    items: result.kitAdded.length,
  );
}
