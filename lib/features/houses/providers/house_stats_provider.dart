import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/items/providers/item_provider.dart';
import '../../../features/trips/providers/trip_provider.dart';

part 'house_stats_provider.g.dart';

/// Statistiche per una casa
class HouseStats {
  final int totalItems;
  final bool hasItemsInTrip;
  final bool hasTemporaryItems;

  const HouseStats({
    required this.totalItems,
    required this.hasItemsInTrip,
    required this.hasTemporaryItems,
  });
}

/// Provider che calcola le statistiche per una casa specifica.
///
/// Usa `.wait` su record Dart 3 per attendere [itemNotifierProvider] e
/// [tripNotifierProvider] in parallelo anziché in waterfall sequenziale.
/// Propaga correttamente il loading: se uno dei due è ancora in caricamento,
/// [houseStats] rimane pending invece di restituire dati parziali con `value ?? []`.
@riverpod
Future<HouseStats> houseStats(Ref ref, String houseId) async {
  final (items, trips) = await (
    ref.watch(itemNotifierProvider(houseId).future),
    ref.watch(tripNotifierProvider.future),
  ).wait;

  // Filtra solo i viaggi effettivamente in corso (non upcoming né completed)
  final activeTrips = trips.where((trip) => trip.isActive).toList();

  // Calcola se ci sono oggetti della casa in viaggio
  bool hasItemsInTrip = false;
  for (final trip in activeTrips) {
    final hasItemsFromThisHouse = trip.items.any(
      (item) => item.originHouseId == houseId,
    );
    if (hasItemsFromThisHouse) {
      hasItemsInTrip = true;
      break;
    }
  }

  // Calcola se ci sono oggetti temporanei (da altre case)
  bool hasTemporaryItems = false;
  for (final trip in activeTrips) {
    if (trip.destinationHouseId == houseId) {
      final hasItemsFromOtherHouses = trip.items.any(
        (item) => item.originHouseId != houseId,
      );
      if (hasItemsFromOtherHouses) {
        hasTemporaryItems = true;
        break;
      }
    }
  }

  return HouseStats(
    totalItems: items.length,
    hasItemsInTrip: hasItemsInTrip,
    hasTemporaryItems: hasTemporaryItems,
  );
}
