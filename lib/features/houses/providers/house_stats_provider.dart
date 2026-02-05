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

/// Provider che calcola le statistiche per una casa specifica
@Riverpod(keepAlive: true)
Future<HouseStats> houseStats(Ref ref, String houseId) async {
  // Ottieni tutti gli oggetti della casa
  final itemsAsync = ref.watch(itemNotifierProvider(houseId));
  final items = itemsAsync.value ?? [];
  
  // Ottieni tutti i viaggi
  final tripsAsync = await ref.watch(tripNotifierProvider.future);
  
  // Filtra solo i viaggi attivi (non completati)
  final activeTrips = tripsAsync.where((trip) => !trip.isCompleted).toList();
  
  // Calcola se ci sono oggetti della casa in viaggio
  bool hasItemsInTrip = false;
  for (final trip in activeTrips) {
    // Controlla se il viaggio contiene oggetti che originano da questa casa
    final hasItemsFromThisHouse = trip.items.any((item) => item.originHouseId == houseId);
    if (hasItemsFromThisHouse) {
      hasItemsInTrip = true;
      break;
    }
  }
  
  // Calcola se ci sono oggetti temporanei (da altre case)
  bool hasTemporaryItems = false;
  for (final trip in activeTrips) {
    // Controlla se il viaggio è destinato a questa casa
    // e contiene oggetti che NON originano da questa casa
    if (trip.destinationHouseId == houseId) {
      final hasItemsFromOtherHouses = trip.items.any((item) => item.originHouseId != houseId);
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
