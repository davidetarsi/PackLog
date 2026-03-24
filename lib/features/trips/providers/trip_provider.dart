import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../items/repositories/item_repository.dart';
import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';

part 'trip_provider.g.dart';

@Riverpod(keepAlive: true)
class TripNotifier extends _$TripNotifier {
  TripRepository? repository;

  @override
  Future<List<TripModel>> build() async {
    repository ??= ref.watch(tripRepositoryProvider);
    final List<TripModel> trips = await repository!.getAllTrips();

    // Trasferisce gli item alla casa di destinazione per i viaggi appena
    // completati. Questa logica è idempotente: controlla se l'item è già
    // stato spostato prima di agire, quindi è sicura da rieseguire a ogni
    // rebuild (es. al riavvio dell'app).
    await _transferItemsForCompletedTrips(trips);

    // Pianifica un refresh automatico al prossimo cambio di stato:
    // - quando un viaggio "upcoming" diventa "active" (partenza)
    // - quando un viaggio "active" diventa "completed" (ritorno)
    // In questo modo l'UI si aggiorna esattamente al momento giusto,
    // senza polling continuo e senza richiedere interazione dell'utente.
    _scheduleRefreshForNextStatusChange(trips);

    return trips;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRIP LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Trasferisce automaticamente gli item alla casa di destinazione quando
  /// un viaggio viene completato, usando un bulk UPDATE per gruppo di origine.
  ///
  /// **Correttezza garantita dal filtro SQL**: la query include
  /// `AND house_id = fromHouseId`, quindi vengono spostati *solo* gli item
  /// che si trovano ancora nella casa di partenza del viaggio. Item già
  /// trasferiti in precedenti rebuild, manualmente ricollocati, o attualmente
  /// in un altro viaggio attivo vengono ignorati automaticamente. Questo
  /// previene il bug "item spariti" che si verificava su pull-to-refresh
  /// quando un viaggio completato (trip vecchio) e uno attivo (trip corrente)
  /// condividevano gli stessi item.
  ///
  /// **Raggruppamento per originHouseId**: item di uno stesso viaggio possono
  /// provenire da case diverse. Raggruppiamo prima per evitare query ridondanti
  /// e mantenere il numero di round-trip pari al numero di case di origine
  /// distinte (tipicamente 1 per viaggio), non al numero di item.
  ///
  /// Criteri di selezione:
  /// - Viaggio completato con [TripModel.destinationHouseId] valorizzato.
  /// - [TripItem.originHouseId] non vuoto (retrocompat dati vecchi).
  /// - Origine ≠ destinazione (i viaggi "locali" non trasferiscono nulla).
  Future<void> _transferItemsForCompletedTrips(List<TripModel> trips) async {
    final ItemRepository itemRepo = ref.read(itemRepositoryProvider);

    for (final TripModel trip in trips) {
      if (!trip.isCompleted) continue;
      if (trip.destinationHouseId == null) continue;
      if (trip.items.isEmpty) continue;

      // Raggruppa i candidati per casa di origine per emettere una query
      // SQL per gruppo, anziché una per item (pattern N+1).
      final Map<String, List<String>> idsByOrigin = {};
      for (final TripItem i in trip.items) {
        if (i.originHouseId.isEmpty) continue;
        if (i.originHouseId == trip.destinationHouseId) continue;
        idsByOrigin.putIfAbsent(i.originHouseId, () => []).add(i.id);
      }

      if (idsByOrigin.isEmpty) continue;

      for (final MapEntry<String, List<String>> entry in idsByOrigin.entries) {
        try {
          await itemRepo.moveItemsToHouse(
            entry.value,
            entry.key,               // fromHouseId: filtra nel WHERE SQL
            trip.destinationHouseId!, // toHouseId
          );
          debugPrint(
            '[TripNotifier] ${entry.value.length} item(s) spostati '
            '${entry.key} → ${trip.destinationHouseId} (viaggio: ${trip.id})',
          );
        } catch (e) {
          debugPrint(
            '[TripNotifier] Errore nel trasferimento batch '
            '${entry.key} → ${trip.destinationHouseId}: $e',
          );
        }
      }
    }
  }

  /// Pianifica [ref.invalidateSelf] al prossimo cambio di stato dei viaggi.
  ///
  /// Considera due eventi:
  /// - Partenza di un viaggio upcoming (diventa active).
  /// - Ritorno di un viaggio active (diventa completed).
  ///
  /// Il timer è a singolo scatto e viene cancellato automaticamente tramite
  /// [ref.onDispose] se il provider viene rebuiltato o eliminato prima che
  /// scatti, prevenendo accessi a provider già invalidati.
  void _scheduleRefreshForNextStatusChange(List<TripModel> trips) {
    final DateTime now = DateTime.now();
    DateTime? nextChange;

    for (final TripModel trip in trips) {
      // Partenza imminente: upcoming → active
      if (trip.isUpcoming && trip.departureDateTime != null) {
        final DateTime dt = trip.departureDateTime!;
        if (dt.isAfter(now)) {
          if (nextChange == null || dt.isBefore(nextChange)) nextChange = dt;
        }
      }

      // Ritorno imminente: active → completed
      if (trip.isActive && trip.returnDateTime != null) {
        final DateTime dt = trip.returnDateTime!;
        if (dt.isAfter(now)) {
          if (nextChange == null || dt.isBefore(nextChange)) nextChange = dt;
        }
      }
    }

    if (nextChange != null) {
      // +2 secondi di buffer per assorbire imprecisioni del sistema operativo
      // nell'esecuzione dei timer in background.
      final Duration delay =
          nextChange.difference(now) + const Duration(seconds: 2);

      final Timer timer = Timer(delay, () {
        debugPrint('[TripNotifier] Auto-refresh: cambio di stato viaggio');
        ref.invalidateSelf();
      });

      // Garantisce che il timer venga cancellato se il provider viene
      // rebuiltato (es. a seguito di un updateTrip) prima che scatti,
      // evitando chiamate a ref su un provider già invalidato.
      ref.onDispose(timer.cancel);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> addTrip(TripModel model) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addTrip(model);
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateTrip(TripModel model) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateTrip(model);
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteTrip(String id) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteTrip(id);
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> toggleItemCheck(String tripId, String itemId) async {
    repository ??= ref.read(tripRepositoryProvider);
    try {
      final List<TripModel>? trips = state.value;
      if (trips == null) return;

      final int tripIndex = trips.indexWhere((t) => t.id == tripId);
      if (tripIndex == -1) return;

      final TripModel trip = trips[tripIndex];
      final int itemIndex = trip.items.indexWhere((i) => i.id == itemId);
      if (itemIndex == -1) return;

      final List<TripItem> updatedItems = [...trip.items];
      updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
        isChecked: !updatedItems[itemIndex].isChecked,
      );

      final TripModel updatedTrip = trip.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      await repository!.updateTrip(updatedTrip);
      final List<TripModel> newTrips = await repository!.getAllTrips();
      state = AsyncData(newTrips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Duplica un viaggio (Deep Copy: viaggio + tutti gli items).
  ///
  /// Returns: ID del nuovo viaggio creato.
  Future<String> duplicateTrip(String tripId) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      final String newTripId = await repository!.duplicateTrip(tripId);
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
      return newTripId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refresh() async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Toggle dello stato salvato/preferito di un viaggio.
  Future<void> toggleSaved(String tripId) async {
    repository ??= ref.read(tripRepositoryProvider);
    try {
      final List<TripModel>? trips = state.value;
      if (trips == null) return;

      final int tripIndex = trips.indexWhere((t) => t.id == tripId);
      if (tripIndex == -1) return;

      final TripModel trip = trips[tripIndex];
      final TripModel updatedTrip = trip.copyWith(
        isSaved: !trip.isSaved,
        updatedAt: DateTime.now(),
      );

      await repository!.updateTrip(updatedTrip);
      final List<TripModel> newTrips = await repository!.getAllTrips();
      state = AsyncData(newTrips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
