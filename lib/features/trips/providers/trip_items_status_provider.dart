import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../items/providers/item_provider.dart';

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
    // Loading silenzioso: il badge "in viaggio" sull'item è assente mentre i trip
    // caricano. Meno fastidioso visivamente di uno skeleton inline nella lista item.
    loading: () => ItemTripStatus.notOnTrip,
    // Error silenzioso: se i trip falliscono, l'item appare "non in viaggio".
    // L'errore è visibile altrove (trip list), non serve duplicarlo sui badge.
    error: (e, s) => ItemTripStatus.notOnTrip,
  );
}

/// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica.
///
/// Retrocompatibilità: item con [TripItem.originHouseId] vuoto (creati con versioni
/// precedenti dell'app) vengono considerati appartenenti a questa casa se l'[ItemModel]
/// corrispondente è attualmente in essa. Questo evita che oggetti "orfani" scompaiano
/// dai badge "in viaggio" dopo aggiornamenti dello schema dati.
@riverpod
Set<String> itemsOnTripFromHouse(Ref ref, String houseId) {
  final tripsAsync = ref.watch(tripNotifierProvider);
  // Fallback retrocompatibilità: item con originHouseId vuoto vengono risolti
  // verificando a quale casa appartiene effettivamente l'ItemModel.
  final houseItemIdSet =
      ref
          .watch(itemNotifierProvider(houseId))
          .valueOrNull
          ?.map((i) => i.id)
          .toSet() ??
      {};

  return tripsAsync.when(
    data: (trips) {
      final itemIds = <String>{};
      for (final trip in trips) {
        if (trip.isActive) {
          for (final item in trip.items) {
            final belongsToThisHouse =
                item.originHouseId == houseId ||
                (item.originHouseId.isEmpty &&
                    houseItemIdSet.contains(item.id));
            if (belongsToThisHouse) {
              itemIds.add(item.id);
            }
          }
        }
      }
      return itemIds;
    },
    // Loading silenzioso: zero item "in viaggio" mentre i trip caricano.
    // I badge della house detail non mostrano skeleton — appaiono direttamente
    // quando i dati sono pronti.
    loading: () => <String>{},
    error: (e, s) => <String>{},
  );
}

/// Provider che fornisce le quantità in viaggio per ogni item di una casa.
/// Restituisce una mappa {itemId: quantitàInViaggio}.
/// Per ogni item, considera solo la quantità del viaggio PIÙ RECENTE che lo contiene,
/// non la somma di tutti i viaggi (per gestire viaggi sovrapposti).
///
/// Applica la stessa logica di retrocompatibilità di [itemsOnTripFromHouseProvider]:
/// item con [TripItem.originHouseId] vuoto vengono risolti tramite [itemNotifierProvider].
@riverpod
Map<String, int> itemQuantitiesOnTripFromHouse(Ref ref, String houseId) {
  final tripsAsync = ref.watch(tripNotifierProvider);
  final houseItemIdSet =
      ref
          .watch(itemNotifierProvider(houseId))
          .valueOrNull
          ?.map((i) => i.id)
          .toSet() ??
      {};

  return tripsAsync.when(
    data: (trips) {
      final quantities = <String, int>{};
      // Raccogli tutti gli item unici in viaggi attivi dalla casa specificata
      final itemIds = <String>{};
      for (final trip in trips) {
        if (trip.isActive) {
          for (final item in trip.items) {
            final belongsToThisHouse =
                item.originHouseId == houseId ||
                (item.originHouseId.isEmpty &&
                    houseItemIdSet.contains(item.id));
            if (belongsToThisHouse) {
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
    // Loading silenzioso: mappa vuota mentre i trip caricano.
    // Stesso rationale di [itemsOnTripFromHouseProvider].
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
    // Loading silenzioso: sezione "item temporanei" assente mentre i trip caricano.
    // Meno fastidioso di un placeholder vuoto che appare e scompare.
    loading: () => [],
    error: (e, s) => [],
  );
}
