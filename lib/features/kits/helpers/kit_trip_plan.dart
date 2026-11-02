import '../../items/model/item_model.dart';
import '../../trips/model/trip_model.dart';
import '../model/kit_model.dart';

/// Cosa cambia in un viaggio quando ci si mette un kit a mano.
class KitTripPlan {
  const KitTripPlan({required this.toAdd, required this.raised});

  /// Gli oggetti che nel viaggio non ci sono.
  final List<TripItem> toAdd;

  /// Le copie nuove (id oggetto → copie) di quelli già nel viaggio che ne
  /// avevano meno.
  final Map<String, int> raised;

  int get changes => toAdd.length + raised.length;
}

/// Le copie sono quelle del kit, ma mai più di quante ne ha la casa; un
/// oggetto già nel viaggio prende il massimo fra le sue copie e quelle del
/// kit, mai la somma. Gli oggetti del kit che la casa non ha più si saltano.
KitTripPlan planKitForTrip({
  required KitModel kit,
  required List<ItemModel> houseItems,
  required TripModel trip,
}) {
  final byId = {for (final item in houseItems) item.id: item};
  final onTrip = {for (final item in trip.items) item.id: item};
  final toAdd = <TripItem>[];
  final raised = <String, int>{};
  for (final line in kit.items) {
    final item = byId[line.itemId];
    if (item == null) continue;
    final inHouse = item.quantity ?? 1;
    final wanted = line.copies < inHouse ? line.copies : inHouse;
    final existing = onTrip[item.id];
    if (existing == null) {
      toAdd.add(
        TripItem(
          id: item.id,
          name: item.name,
          category: item.category,
          quantity: wanted,
          originHouseId: item.houseId,
        ),
      );
    } else if (existing.quantity < wanted) {
      raised[item.id] = wanted;
    }
  }
  return KitTripPlan(toAdd: toAdd, raised: raised);
}

/// Il viaggio con il piano applicato, per `updateTrip` (che sostituisce tutte
/// le righe): le righe esistenti con le copie alzate, poi quelle nuove.
TripModel applyKitTripPlan(TripModel trip, KitTripPlan plan) => trip.copyWith(
  items: [
    for (final item in trip.items)
      plan.raised.containsKey(item.id)
          ? item.copyWith(quantity: plan.raised[item.id]!)
          : item,
    ...plan.toAdd,
  ],
  updatedAt: DateTime.now(),
);
