import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../services/trip_lifecycle_service.dart';

part 'trip_provider.g.dart';

@Riverpod(keepAlive: true)
class TripNotifier extends _$TripNotifier {
  TripRepository? repository;

  @override
  Future<List<TripModel>> build() async {
    repository = ref.watch(tripRepositoryProvider);
    ref.watch(syncTriggerProvider);
    final List<TripModel> trips = await repository!.getAllTrips();

    final TripLifecycleService lifecycle = ref.read(
      tripLifecycleServiceProvider,
    );

    // Trasferisce gli item alla casa di destinazione per i viaggi completati.
    // Idempotente: il filtro SQL in moveItemsToHouse esclude item già spostati.
    final Set<String> affectedHouseIds = await lifecycle
        .transferItemsForCompletedTrips(trips);
    if (affectedHouseIds.isNotEmpty) {
      // I record toccati da moveItemsToHouse sono ora `pendingUpdate`:
      // chiediamo subito un push così la tile "Stato sincronizzazione" e il
      // dialog di logout riflettono il vero stato senza attendere il
      // prossimo trigger (mutazione utente, app_resume, connectivity).
      ref.read(syncOrchestratorProvider).requestSync();
    }

    // Auto-refresh allo scatto del prossimo cambio di status (upcoming→active
    // o active→completed). Timer locale al provider, cancellato in onDispose.
    _scheduleRefreshAt(lifecycle.computeNextStatusChange(trips));

    return trips;
  }

  void _scheduleRefreshAt(DateTime? at) {
    if (at == null) return;
    // +2s buffer per assorbire imprecisioni di scheduling del SO.
    final Duration delay =
        at.difference(DateTime.now()) + const Duration(seconds: 2);
    final Timer timer = Timer(delay, () {
      debugPrint('[TripNotifier] Auto-refresh: cambio di stato viaggio');
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
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
      ref
          .read(coreAnalyticsServiceProvider)
          .trackTripCreated(tripId: model.id, totalTrips: trips.length);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateTrip(TripModel model) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateTrip(model);
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
      ref.read(coreAnalyticsServiceProvider).trackTripUpdated();
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTrip(String id) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteTrip(id);
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
      ref.read(coreAnalyticsServiceProvider).trackTripDeleted();
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
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

      final bool newChecked = !trip.items[itemIndex].isChecked;

      // Optimistic state update: l'UI riflette il toggle subito, senza
      // ricaricare tutta la lista trip dal DB.
      final List<TripItem> updatedItems = [...trip.items];
      updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
        isChecked: newChecked,
      );
      final TripModel updatedTrip = trip.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      final List<TripModel> newTrips = [...trips];
      newTrips[tripIndex] = updatedTrip;
      state = AsyncData(newTrips);

      // Fast-path persistenza: una sola colonna toccata invece di
      // `replaceTripItems` (DELETE all + INSERT all) seguito da
      // `getAllTrips()`. Path caldo durante il packing.
      await repository!.setTripItemChecked(tripId, itemId, newChecked);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Duplica un viaggio (Deep Copy: viaggio + tutti gli items).
  ///
  /// Returns: ID del nuovo viaggio creato.
  Future<String> duplicateTrip(String tripId, {String? nameSuffix}) async {
    repository ??= ref.read(tripRepositoryProvider);
    state = const AsyncLoading();
    try {
      final String newTripId = await repository!.duplicateTrip(
        tripId,
        nameSuffix: nameSuffix ?? ' (Copia)',
      );
      final List<TripModel> trips = await repository!.getAllTrips();
      state = AsyncData(trips);
      ref.read(coreAnalyticsServiceProvider).trackTripDuplicated();
      ref.read(syncOrchestratorProvider).requestSync();
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
      // No rethrow: refresh() is wired to ErrorState.onRetry (VoidCallback).
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
      ref
          .read(coreAnalyticsServiceProvider)
          .trackTripSavedToggled(isSaved: updatedTrip.isSaved);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
