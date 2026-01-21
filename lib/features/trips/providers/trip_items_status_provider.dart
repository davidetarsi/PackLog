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

/// Trova il viaggio attivo più recente (per data di partenza) che contiene un item specifico
TripModel? _findMostRecentActiveTrip(List<TripModel> trips, String itemId) {
  TripModel? mostRecent;
  DateTime? mostRecentDeparture;

  for (final trip in trips) {
    if (trip.isActive) {
      final containsItem = trip.items.any((item) => item.id == itemId);
      if (containsItem) {
        final departure = trip.departureDateTime;
        if (mostRecent == null ||
            (departure != null &&
                (mostRecentDeparture == null ||
                    departure.isAfter(mostRecentDeparture)))) {
          mostRecent = trip;
          mostRecentDeparture = departure;
        }
      }
    }
  }
  return mostRecent;
}

/// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
/// Considera il viaggio più recente come quello determinante per lo stato dell'item
@riverpod
ItemTripStatus itemTripStatus(Ref ref, String itemId) {
  final tripsAsync = ref.watch(tripNotifierProvider);

  return tripsAsync.when(
    data: (trips) {
      // Trova il viaggio attivo più recente che contiene questo item
      final mostRecentTrip = _findMostRecentActiveTrip(trips, itemId);
      if (mostRecentTrip != null) {
        return ItemTripStatus(
          isOnTrip: true,
          activeTripId: mostRecentTrip.id,
          activeTripName: mostRecentTrip.name,
          destinationHouseId: mostRecentTrip.destinationHouseId,
        );
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

/// Provider che fornisce le quantità in viaggio per ogni item di una casa
/// Restituisce una mappa {itemId: quantitàInViaggio}
/// Per ogni item, considera solo la quantità del viaggio PIÙ RECENTE che lo contiene,
/// non la somma di tutti i viaggi (per gestire viaggi sovrapposti)
@riverpod
Map<String, int> itemQuantitiesOnTripFromHouse(Ref ref, String houseId) {
  final tripsAsync = ref.watch(tripNotifierProvider);

  return tripsAsync.when(
    data: (trips) {
      final quantities = <String, int>{};
      // Raccogli tutti gli item unici in viaggi attivi dalla casa specificata
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

      // Per ogni item, trova il viaggio più recente e usa la sua quantità
      for (final itemId in itemIds) {
        final mostRecentTrip = _findMostRecentActiveTrip(trips, itemId);
        if (mostRecentTrip != null) {
          final tripItem = mostRecentTrip.items.firstWhere(
            (i) => i.id == itemId,
          );
          quantities[itemId] = tripItem.quantity;
        }
      }
      return quantities;
    },
    loading: () => <String, int>{},
    error: (e, s) => <String, int>{},
  );
}

/// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
/// Un item è temporaneo in una casa solo se il viaggio PIÙ RECENTE che lo contiene
/// ha questa casa come destinazione.
/// Se l'item è in un viaggio più recente con destinazione diversa (o senza destinazione),
/// non deve apparire come temporaneo in questa casa.
@riverpod
List<TripItem> temporaryItemsInHouse(Ref ref, String houseId) {
  final tripsAsync = ref.watch(tripNotifierProvider);

  return tripsAsync.when(
    data: (trips) {
      final items = <TripItem>[];

      // Per ogni viaggio attivo con questa casa come destinazione
      for (final trip in trips) {
        if (trip.isActive && trip.destinationHouseId == houseId) {
          // Per ogni item in questo viaggio
          for (final item in trip.items) {
            // Verifica se questo è il viaggio più recente per questo item
            final mostRecentTrip = _findMostRecentActiveTrip(trips, item.id);
            // Aggiungi l'item solo se questo viaggio è quello più recente per l'item
            if (mostRecentTrip?.id == trip.id) {
              items.add(item);
            }
          }
        }
      }
      return items;
    },
    loading: () => [],
    error: (e, s) => [],
  );
}
