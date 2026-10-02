import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/monitoring/monitoring_service.dart';
import '../../items/repositories/item_repository.dart';
import '../model/trip_model.dart';

part 'trip_lifecycle_service.g.dart';

/// Servizio responsabile delle policy *post-build* sui viaggi:
/// - trasferimento automatico item per i viaggi completati (origin → destination);
/// - calcolo del prossimo cambio di status per pianificare un auto-refresh.
///
/// Estratto da `TripNotifier` per separare la logica di policy
/// (testabile in isolamento, senza Riverpod ref) dall'orchestrazione di stato.
class TripLifecycleService {
  TripLifecycleService({
    required this.itemRepository,
    required this.monitoringService,
  });

  final ItemRepository itemRepository;
  final AppMonitoringService monitoringService;

  /// Trasferisce gli item alla casa di destinazione per i viaggi completati,
  /// raggruppando per `originHouseId` (una `UPDATE` per gruppo, no N+1).
  ///
  /// Ritorna l'insieme degli `houseId` toccati con successo
  /// (origin + destination per ogni gruppo spostato), così che il chiamante
  /// possa invalidare i provider corrispondenti.
  ///
  /// La correttezza è garantita dal filtro SQL in
  /// [ItemRepository.moveItemsToHouse]: `house_id = fromHouseId`. Item già
  /// trasferiti o manualmente ricollocati vengono ignorati. Idempotente.
  Future<Set<String>> transferItemsForCompletedTrips(
    List<TripModel> trips,
  ) async {
    final Set<String> affectedHouseIds = {};

    for (final TripModel trip in trips) {
      if (!trip.isCompleted) continue;
      if (trip.destinationHouseId == null) continue;
      if (trip.items.isEmpty) continue;

      final Map<String, List<String>> idsByOrigin = {};
      for (final TripItem i in trip.items) {
        if (i.originHouseId.isEmpty) continue;
        if (i.originHouseId == trip.destinationHouseId) continue;
        idsByOrigin.putIfAbsent(i.originHouseId, () => []).add(i.id);
      }

      if (idsByOrigin.isEmpty) continue;

      for (final MapEntry<String, List<String>> entry in idsByOrigin.entries) {
        try {
          await itemRepository.moveItemsToHouse(
            entry.value,
            entry.key,
            trip.destinationHouseId!,
          );
          affectedHouseIds.add(entry.key);
          affectedHouseIds.add(trip.destinationHouseId!);
          debugPrint(
            '[TripLifecycleService] ${entry.value.length} item(s) spostati '
            '${entry.key} → ${trip.destinationHouseId} (viaggio: ${trip.id})',
          );
        } catch (e, st) {
          debugPrint(
            '[TripLifecycleService] Errore nel trasferimento batch '
            '${entry.key} → ${trip.destinationHouseId}: $e',
          );
          monitoringService.captureException(
            e,
            stackTrace: st,
            tags: {
              'operation': 'auto_transfer_items',
              'trip_id': trip.id,
              'from_house': entry.key,
              'to_house': trip.destinationHouseId!,
            },
          );
        }
      }
    }

    return affectedHouseIds;
  }

  /// Calcola il prossimo istante in cui un viaggio dovrebbe cambiare status:
  /// - upcoming → active al `departureDateTime` futuro;
  /// - active → completed al `returnDateTime` futuro.
  ///
  /// Ritorna `null` se nessun cambio futuro è programmato.
  /// Il chiamante è responsabile di schedulare un `Timer` su questo istante
  /// (e di cancellarlo via `ref.onDispose`).
  DateTime? computeNextStatusChange(List<TripModel> trips) {
    final DateTime now = DateTime.now();
    DateTime? nextChange;

    for (final TripModel trip in trips) {
      if (trip.isUpcoming && trip.departureDateTime != null) {
        final DateTime dt = trip.departureDateTime!;
        if (dt.isAfter(now)) {
          if (nextChange == null || dt.isBefore(nextChange)) nextChange = dt;
        }
      }

      if (trip.isActive && trip.returnDateTime != null) {
        final DateTime dt = trip.returnDateTime!;
        if (dt.isAfter(now)) {
          if (nextChange == null || dt.isBefore(nextChange)) nextChange = dt;
        }
      }
    }

    return nextChange;
  }
}

@Riverpod(keepAlive: true)
TripLifecycleService tripLifecycleService(Ref ref) {
  return TripLifecycleService(
    itemRepository: ref.watch(itemRepositoryProvider),
    monitoringService: ref.watch(monitoringServiceProvider),
  );
}
