import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../services/trip_lifecycle_service.dart';

part 'trip_provider.g.dart';

@Riverpod(keepAlive: true)
class TripNotifier extends _$TripNotifier with SyncedCrudNotifier<TripModel> {
  TripRepository get _repo => ref.read(tripRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  @override
  Future<List<TripModel>> build() async {
    final TripLifecycleService lifecycle = ref.read(
      tripLifecycleServiceProvider,
    );

    // Trasferisce gli item alla casa di destinazione per i viaggi completati.
    // Idempotente: il filtro SQL in moveItemsToHouse esclude item già spostati.
    final List<TripModel> trips = await _repo.getAllTrips();
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

  @override
  void onMutationSuccess(List<TripModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
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

  Future<void> addTrip(TripModel model) => mutate(
    operation: () => _repo.addTrip(model),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (trips) =>
        _analytics.trackTripCreated(tripId: model.id, totalTrips: trips.length),
  );

  Future<void> updateTrip(TripModel model) => mutate(
    operation: () => _repo.updateTrip(model),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (_) => _analytics.trackTripUpdated(),
  );

  Future<void> addItemsToTrip(String tripId, List<TripItem> items) => mutate(
    operation: () => _repo.addItemsToTrip(tripId, items),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (_) =>
        _analytics.trackItemsAddedToTrip(tripId: tripId, count: items.length),
  );

  Future<void> deleteTrip(String id) => mutate(
    operation: () => _repo.deleteTrip(id),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (_) => _analytics.trackTripDeleted(),
  );

  Future<void> toggleItemCheck(String tripId, String itemId) async {
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
      await _repo.setTripItemChecked(tripId, itemId, newChecked);
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
    late String newTripId;
    await mutate(
      operation: () async {
        newTripId = await _repo.duplicateTrip(
          tripId,
          nameSuffix: nameSuffix ?? ' (Copia)',
        );
      },
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (_) => _analytics.trackTripDuplicated(),
    );
    return newTripId;
  }

  Future<void> refresh() => mutate(
    operation: () async {},
    reload: _repo.getAllTrips,
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );

  /// Toggle dello stato salvato/preferito di un viaggio.
  Future<void> toggleSaved(String tripId) async {
    final List<TripModel>? trips = state.valueOrNull;
    if (trips == null) return;

    final int tripIndex = trips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final TripModel updatedTrip = trips[tripIndex].copyWith(
      isSaved: !trips[tripIndex].isSaved,
      updatedAt: DateTime.now(),
    );
    await mutate(
      operation: () => _repo.updateTrip(updatedTrip),
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (_) =>
          _analytics.trackTripSavedToggled(isSaved: updatedTrip.isSaved),
    );
  }
}
