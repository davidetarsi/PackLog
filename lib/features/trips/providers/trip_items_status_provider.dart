import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';

part 'trip_items_status_provider.g.dart';

/// Informazioni sullo stato di un item in relazione ai viaggi
class ItemTripStatus {
  /// L'item è attualmente in viaggio (assente dalla casa di origine)
  final bool isOnTrip;
  
  /// ID del viaggio attivo che contiene questo item
  final String? activeTripId;
  
  /// Nome del viaggio attivo
  final String? activeTripName;
  
  /// ID della casa di destinazione (se presente)
  final String? destinationHouseId;

  const ItemTripStatus({
    this.isOnTrip = false,
    this.activeTripId,
    this.activeTripName,
    this.destinationHouseId,
  });

  static const ItemTripStatus notOnTrip = ItemTripStatus();
}

/// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
@riverpod
ItemTripStatus itemTripStatus(Ref ref, String itemId) {
  final tripsAsync = ref.watch(tripNotifierProvider);
  
  return tripsAsync.when(
    data: (trips) {
      // Cerca un viaggio attivo che contiene questo item
      for (final trip in trips) {
        if (trip.isActive) {
          final containsItem = trip.items.any((item) => item.id == itemId);
          if (containsItem) {
            return ItemTripStatus(
              isOnTrip: true,
              activeTripId: trip.id,
              activeTripName: trip.name,
              destinationHouseId: trip.destinationHouseId,
            );
          }
        }
      }
      return ItemTripStatus.notOnTrip;
    },
    loading: () => ItemTripStatus.notOnTrip,
    error: (e, s) => ItemTripStatus.notOnTrip,
  );
}

/// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
@riverpod
Set<String> itemsOnTripFromHouse(Ref ref, String houseId) {
  final tripsAsync = ref.watch(tripNotifierProvider);
  
  return tripsAsync.when(
    data: (trips) {
      final itemIds = <String>{};
      for (final trip in trips) {
        if (trip.isActive) {
          for (final item in trip.items) {
            if (item.originHouseId == houseId) {
              itemIds.add(item.id);
            }
          }
        }
      }
      return itemIds;
    },
    loading: () => <String>{},
    error: (e, s) => <String>{},
  );
}

/// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
@riverpod
List<TripItem> temporaryItemsInHouse(Ref ref, String houseId) {
  final tripsAsync = ref.watch(tripNotifierProvider);
  
  return tripsAsync.when(
    data: (trips) {
      final items = <TripItem>[];
      for (final trip in trips) {
        if (trip.isActive && trip.destinationHouseId == houseId) {
          items.addAll(trip.items);
        }
      }
      return items;
    },
    loading: () => [],
    error: (e, s) => [],
  );
}

