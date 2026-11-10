import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/ai_packing.dart';
import '../model/trip_model.dart';
import 'trip_provider.dart';

part 'to_buy_provider.g.dart';

/// Un posto aperto segnato "da comprare" e il viaggio a cui appartiene.
class ToBuyEntry {
  const ToBuyEntry({required this.trip, required this.slot});

  final TripModel trip;
  final AiSlot slot;
}

/// I posti aperti segnati "da comprare" di tutti i viaggi.
///
/// L'ordine segue la partenza più vicina (i viaggi senza data in fondo); dentro
/// un viaggio vengono prima gli importanti. Un posto chiuso, o sparito dopo
/// una rigenerazione, non compare: la lista nasce sempre dai viaggi di adesso.
List<ToBuyEntry> toBuyEntriesOf(List<TripModel> trips) {
  final withDeparture = [...trips]
    ..sort((a, b) {
      final da = a.departureDateTime;
      final db = b.departureDateTime;
      if (da == null && db == null) return a.id.compareTo(b.id);
      if (da == null) return 1;
      if (db == null) return -1;
      final byDate = da.compareTo(db);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  return [for (final trip in withDeparture) ..._entriesOfTrip(trip)];
}

Iterable<ToBuyEntry> _entriesOfTrip(TripModel trip) {
  final slots = (trip.aiResult?.slots ?? const <AiSlot>[])
      .where((slot) => slot.isOpen && slot.toBuy)
      .toList();
  // `sort` non è stabile: gli importanti prima, il resto nell'ordine del viaggio.
  final important = slots.where((s) => s.level == AiSlotLevel.important);
  final useful = slots.where((s) => s.level != AiSlotLevel.important);
  return [
    for (final slot in [...important, ...useful])
      ToBuyEntry(trip: trip, slot: slot),
  ];
}

@riverpod
List<ToBuyEntry> toBuyEntries(Ref ref) {
  final trips = ref.watch(tripNotifierProvider).valueOrNull ?? const [];
  return toBuyEntriesOf(trips);
}
