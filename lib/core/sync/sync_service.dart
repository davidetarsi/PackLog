import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../analytics/core_analytics_service.dart';
import '../database/daos/houses_dao.dart';
import '../database/daos/items_dao.dart';
import '../database/daos/luggages_dao.dart';
import '../database/daos/spaces_dao.dart';
import '../database/daos/trips_dao.dart';
import '../database/database.dart';
import '../database/tables/mixins/syncable_table.dart';
import '../monitoring/monitoring_service.dart';
import '../../shared/helpers/sync_error_reason.dart';
import 'supabase_repository.dart';
import 'sync_serializers.dart';
import 'tombstone_config_service.dart';

/// Snapshot leggibile dall'utente dello stato "non sincronizzato" per un
/// singolo tipo di entità (casa, spazio, bagaglio, oggetto, viaggio).
///
/// [entityLabelKey] e [reasonKey] sono chiavi i18n grezze (non tradotte) —
/// il caller decide dove e come tradurle con `.tr()`.
class SyncEntityStatus {
  const SyncEntityStatus({
    required this.entityLabelKey,
    required this.count,
    required this.reasonKey,
  });

  final String entityLabelKey;
  final int count;
  final String reasonKey;
}

class SyncService {
  final HousesDao _housesDao;
  final ItemsDao _itemsDao;
  final SpacesDao _spacesDao;
  final LuggagesDao _luggagesDao;
  final TripsDao _tripsDao;
  final SupabaseRepository _remote;
  final AppMonitoringService _monitoring;
  final TombstoneConfigService _tombstoneConfig;
  final CoreAnalyticsService? _analytics;

  SyncService({
    required HousesDao housesDao,
    required ItemsDao itemsDao,
    required SpacesDao spacesDao,
    required LuggagesDao luggagesDao,
    required TripsDao tripsDao,
    required SupabaseRepository remote,
    required AppMonitoringService monitoring,
    required TombstoneConfigService tombstoneConfig,
    CoreAnalyticsService? analytics,
  }) : _housesDao = housesDao,
       _itemsDao = itemsDao,
       _spacesDao = spacesDao,
       _luggagesDao = luggagesDao,
       _tripsDao = tripsDao,
       _remote = remote,
       _monitoring = monitoring,
       _tombstoneConfig = tombstoneConfig,
       _analytics = analytics;

  /// Conta tutti i record non sincronizzati (syncStatus != synced) su tutte
  /// le tabelle, indipendentemente dal retry count o dal backoff.
  ///
  /// Usato per decidere se mostrare il pulsante "Sincronizza ora" nel profilo:
  /// anche i record stuck (retry >= 5 o in backoff) contribuiscono al totale,
  /// così il pulsante rimane visibile finché esistono dati non su Supabase.
  Future<int> countAllUnsyncedChanges() async {
    final counts = await Future.wait([
      _housesDao.countUnsynced(),
      _spacesDao.countUnsynced(),
      _luggagesDao.countUnsynced(),
      _itemsDao.countUnsynced(),
      _tripsDao.countUnsynced(),
    ]);
    return counts.fold<int>(0, (sum, n) => sum + n);
  }

  /// Conta le modifiche pending in tutte le tabelle.
  ///
  /// Usato dalla UI di logout per avvertire l'utente se ci sono mutazioni non
  /// ancora pushate al cloud. Considera "pending" qualsiasi record con
  /// syncStatus != synced e retry sotto soglia (lo stesso filtro di
  /// `processQueue`).
  Future<int> countPendingChanges() async {
    final results = await Future.wait([
      _housesDao.getPendingSyncRecords(),
      _spacesDao.getPendingSyncRecords(),
      _luggagesDao.getPendingSyncRecords(),
      _itemsDao.getPendingSyncRecords(),
      _tripsDao.getPendingSyncRecords(),
    ]);
    return results.fold<int>(0, (sum, list) => sum + list.length);
  }

  /// Breakdown per-entità delle modifiche non ancora sincronizzate, per la
  /// UI di dettaglio (dialog "Stato sincronizzazione" nel profilo).
  ///
  /// Riusa [getPendingSyncRecords] — stessa semantica (retry sotto soglia +
  /// backoff rispettato) già usata da [countPendingChanges] per il warning
  /// di logout. Nessuna nuova query SQL.
  ///
  /// Il "reason" mostrato è quello del primo record con `lastSyncError` non
  /// nullo trovato nel gruppo — un singolo rappresentante per tipo di
  /// entità, non un elenco per-record.
  Future<List<SyncEntityStatus>> getUnsyncedBreakdown() async {
    final results = await Future.wait([
      _housesDao.getPendingSyncRecords(),
      _spacesDao.getPendingSyncRecords(),
      _luggagesDao.getPendingSyncRecords(),
      _itemsDao.getPendingSyncRecords(),
      _tripsDao.getPendingSyncRecords(),
    ]);

    const labels = [
      'houses.title',
      'spaces.title',
      'luggages.title',
      'profile.sync_entity_items',
      'trips.title',
    ];

    final breakdown = <SyncEntityStatus>[];
    for (var i = 0; i < results.length; i++) {
      final records = results[i];
      if (records.isEmpty) continue;

      final lastError = records
          .map((r) => (r as dynamic).lastSyncError as String?)
          .firstWhere((e) => e != null, orElse: () => null);

      breakdown.add(
        SyncEntityStatus(
          entityLabelKey: labels[i],
          count: records.length,
          reasonKey: syncErrorReasonKey(lastError),
        ),
      );
    }
    return breakdown;
  }

  /// Wipe completo dei dati locali. Usato all'avvio quando l'utente loggato
  /// non corrisponde a quello dei record salvati (cambio account sul device):
  /// evita che l'utente B veda transitoriamente i dati dell'utente A prima
  /// che il fullPull li sostituisca.
  ///
  /// Ordine: figli prima, padri dopo. La cascade FK sarebbe sufficiente ma
  /// l'ordine esplicito tiene la semantica chiara e non dipende da PRAGMA.
  Future<void> wipeAllUserData() async {
    debugPrint('[SyncService] wipeAllUserData: clearing local DB');
    await _itemsDao.wipeAll();
    await _spacesDao.wipeAll();
    await _luggagesDao.wipeAll();
    await _tripsDao.wipeAll();
    await _housesDao.wipeAll();
    _monitoring.logBreadcrumb(
      'Local DB wiped (account switch)',
      category: 'sync',
    );
  }

  /// Azzera lo stato di retry su tutte le tabelle sincronizzate.
  ///
  /// Chiamato dall'orchestrator quando la connettività torna o l'app viene
  /// ripresa: dà una nuova chance ai record bloccati oltre la soglia di 5
  /// retry, che altrimenti `getPendingSync*` continuerebbe a filtrare.
  Future<int> resetAllSyncRetries() async {
    final count =
        await _housesDao.resetSyncRetries() +
        await _spacesDao.resetSyncRetries() +
        await _luggagesDao.resetSyncRetries() +
        await _itemsDao.resetSyncRetries() +
        await _tripsDao.resetSyncRetries();
    if (count > 0) {
      debugPrint('[SyncService] Reset retry state on $count records');
      _monitoring.logBreadcrumb(
        'Reset retry state on $count blocked records',
        category: 'sync',
        data: {'count': count},
      );
    }
    return count;
  }

  /// One-time recovery: re-marks soft-deleted records that were incorrectly
  /// left as "synced" (due to a prior timezone bug that caused pulls instead
  /// of pushes). After this runs, processQueue will pick them up.
  bool _recoveryDone = false;
  Future<void> _recoverStaleSoftDeletes() async {
    if (_recoveryDone) return;
    _recoveryDone = true;
    final count =
        await _housesDao.markDeletedAsPendingSync() +
        await _spacesDao.markDeletedAsPendingSync() +
        await _luggagesDao.markDeletedAsPendingSync() +
        await _itemsDao.markDeletedAsPendingSync() +
        await _tripsDao.markDeletedAsPendingSync();
    if (count > 0) {
      debugPrint(
        '[SyncService] Recovery: $count stale soft-deleted records re-queued',
      );
    }
  }

  /// Scarica tutti i record dell'utente da Supabase e li applica localmente.
  ///
  /// Eseguito ad ogni avvio (via [SyncOrchestrator.requestFullPull]).
  /// Conflict resolution: remote wins solo se [remote.updatedAt > local.updatedAt].
  /// Record locali più nuovi (pendingSync) vengono lasciati intatti; [processQueue]
  /// li propagherà al cloud al prossimo giro.
  ///
  /// Ordine FK-safe: case → items → viaggi.
  Future<void> fullPull(String userId) async {
    debugPrint('[SyncService] fullPull: avvio per userId=$userId');

    try {
      final results = await Future.wait([
        _remote.fetchAllHousesByUserId(userId),
        _remote.fetchAllSpacesByUserId(userId),
        _remote.fetchAllLuggagesByUserId(userId),
        _remote.fetchAllItemsByUserId(userId),
        _remote.fetchAllTripsByUserId(userId),
      ]);

      final remoteHouses = results[0];
      final remoteSpaces = results[1];
      final remoteLuggages = results[2];
      final remoteItems = results[3];
      final remoteTrips = results[4];
      final now = DateTime.now();
      int inserted = 0, updated = 0, skipped = 0;

      for (final r in remoteHouses) {
        final id = r['id'] as String;
        try {
          final remoteTs = DateTime.parse(r['updated_at'] as String).toUtc();
          final remoteIsDeleted = r['is_deleted'] as bool? ?? false;
          final local = await _housesDao.findHouseById(id);
          if (local == null) {
            // Tombstone per record mai conosciuto: niente da soft-deletare.
            if (remoteIsDeleted) {
              skipped++;
              continue;
            }
            await _housesDao.insertHouse(
              SyncSerializers.buildHouseCompanion(r, syncedAt: now),
            );
            inserted++;
          } else if (local.isDeleted && !remoteIsDeleted) {
            // Delete-wins (stessa regola di _syncRecord): il tombstone locale
            // non viene mai sovrascritto da un remoto vivo, anche se più
            // recente. processQueue pusherà la cancellazione al prossimo giro.
            skipped++;
          } else if (remoteTs.isAfter(local.updatedAt.toUtc())) {
            await _housesDao.updateHouse(
              SyncSerializers.buildHouseCompanion(r, syncedAt: now),
            );
            updated++;
          } else {
            skipped++;
          }
        } catch (e, st) {
          debugPrint(
            '[SyncService] fullPull: skip house $id — ${e.runtimeType}',
          );
          _monitoring.captureException(
            e,
            stackTrace: st,
            tags: {'operation': 'fullPull_house', 'house_id': id},
          );
        }
      }

      // FK-safe order: houses → spaces → luggages → items → trips.
      for (final r in remoteSpaces) {
        final id = r['id'] as String;
        try {
          final remoteTs = DateTime.parse(r['updated_at'] as String).toUtc();
          final remoteIsDeleted = r['is_deleted'] as bool? ?? false;
          final local = await _spacesDao.findSpaceById(id);
          if (local == null) {
            if (remoteIsDeleted) {
              skipped++;
              continue;
            }
            await _spacesDao.insertSpace(
              SyncSerializers.buildSpaceCompanion(r, syncedAt: now),
            );
            inserted++;
          } else if (local.isDeleted && !remoteIsDeleted) {
            skipped++; // delete-wins: vedi loop houses
          } else if (remoteTs.isAfter(local.updatedAt.toUtc())) {
            await _spacesDao.updateSpace(
              SyncSerializers.buildSpaceCompanion(r, syncedAt: now),
            );
            updated++;
          } else {
            skipped++;
          }
        } catch (e, st) {
          debugPrint(
            '[SyncService] fullPull: skip space $id — ${e.runtimeType}',
          );
          _monitoring.captureException(
            e,
            stackTrace: st,
            tags: {'operation': 'fullPull_space', 'space_id': id},
          );
        }
      }

      for (final r in remoteLuggages) {
        final id = r['id'] as String;
        try {
          final remoteTs = DateTime.parse(r['updated_at'] as String).toUtc();
          final remoteIsDeleted = r['is_deleted'] as bool? ?? false;
          final local = await _luggagesDao.findLuggageById(id);
          if (local == null) {
            if (remoteIsDeleted) {
              skipped++;
              continue;
            }
            await _luggagesDao.insertLuggage(
              SyncSerializers.buildLuggageCompanion(r, syncedAt: now),
            );
            inserted++;
          } else if (local.isDeleted && !remoteIsDeleted) {
            skipped++; // delete-wins: vedi loop houses
          } else if (remoteTs.isAfter(local.updatedAt.toUtc())) {
            await _luggagesDao.updateLuggage(
              SyncSerializers.buildLuggageCompanion(r, syncedAt: now),
            );
            updated++;
          } else {
            skipped++;
          }
        } catch (e, st) {
          debugPrint(
            '[SyncService] fullPull: skip luggage $id — ${e.runtimeType}',
          );
          _monitoring.captureException(
            e,
            stackTrace: st,
            tags: {'operation': 'fullPull_luggage', 'luggage_id': id},
          );
        }
      }

      for (final r in remoteItems) {
        final id = r['id'] as String;
        try {
          final remoteTs = DateTime.parse(r['updated_at'] as String).toUtc();
          final remoteIsDeleted = r['is_deleted'] as bool? ?? false;
          final local = await _itemsDao.findItemById(id);
          if (local == null) {
            if (remoteIsDeleted) {
              skipped++;
              continue;
            }
            await _persistItemWithFkFallback(r, syncedAt: now, isInsert: true);
            inserted++;
          } else if (local.isDeleted && !remoteIsDeleted) {
            skipped++; // delete-wins: vedi loop houses
          } else if (remoteTs.isAfter(local.updatedAt.toUtc())) {
            await _persistItemWithFkFallback(r, syncedAt: now, isInsert: false);
            updated++;
          } else {
            skipped++;
          }
        } catch (e, st) {
          // FK violation residua: tipicamente la casa di questo item non
          // esiste ancora localmente. Tracciamo per visibilità — il silent
          // skip storico nascondeva perdite di dati al primo restore.
          debugPrint(
            '[SyncService] fullPull: skip item $id — ${e.runtimeType}',
          );
          _monitoring.captureException(
            e,
            stackTrace: st,
            tags: {'operation': 'fullPull_item', 'item_id': id},
          );
        }
      }

      for (final r in remoteTrips) {
        final id = r['id'] as String;
        try {
          final remoteTs = DateTime.parse(r['updated_at'] as String).toUtc();
          final remoteIsDeleted = r['is_deleted'] as bool? ?? false;
          final local = await _tripsDao.findTripById(id);
          if (local == null) {
            if (remoteIsDeleted) {
              skipped++;
              continue;
            }
            await _tripsDao.insertTrip(
              SyncSerializers.buildTripCompanion(r, syncedAt: now),
            );
            await _replaceTripItemsFromJson(id, r['items']);
            await _replaceTripLuggagesFromJson(id, r['luggage_ids']);
            inserted++;
          } else if (local.isDeleted && !remoteIsDeleted) {
            skipped++; // delete-wins: vedi loop houses
          } else if (remoteTs.isAfter(local.updatedAt.toUtc())) {
            await _tripsDao.updateTrip(
              SyncSerializers.buildTripCompanion(r, syncedAt: now),
            );
            await _replaceTripItemsFromJson(id, r['items']);
            await _replaceTripLuggagesFromJson(id, r['luggage_ids']);
            updated++;
          } else {
            skipped++;
          }
        } catch (e, st) {
          debugPrint(
            '[SyncService] fullPull: skip trip $id — ${e.runtimeType}',
          );
          _monitoring.captureException(
            e,
            stackTrace: st,
            tags: {'operation': 'fullPull_trip', 'trip_id': id},
          );
        }
      }

      _monitoring.logBreadcrumb(
        'fullPull: $inserted inseriti, $updated aggiornati, $skipped invariati',
        category: 'sync',
        data: {
          'inserted': inserted,
          'updated': updated,
          'skipped': skipped,
          'remote_houses': remoteHouses.length,
          'remote_items': remoteItems.length,
          'remote_trips': remoteTrips.length,
        },
      );
      debugPrint(
        '[SyncService] fullPull completato: $inserted inseriti, $updated aggiornati, $skipped invariati',
      );
    } catch (e, st) {
      debugPrint('[SyncService] fullPull fallita: $e');
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: const {'operation': 'fullPull'},
      );
      rethrow;
    }
  }

  /// FK-safe order: houses → spaces → luggages → items → trips (create/update).
  /// Purge order is reversed: trips/items/luggages/spaces first, houses last
  /// (FK safety: items reference spaces; trips reference luggages via junction).
  Future<void> processQueue() async {
    await _recoverStaleSoftDeletes();
    final houses = await _housesDao.getPendingSyncRecords();
    final spaces = await _spacesDao.getPendingSyncRecords();
    final luggages = await _luggagesDao.getPendingSyncRecords();
    final items = await _itemsDao.getPendingSyncRecords();
    final trips = await _tripsDao.getPendingSyncRecords();

    _monitoring.logBreadcrumb(
      'Avvio batch sync: ${houses.length} case, ${spaces.length} spazi, '
      '${luggages.length} bagagli, ${items.length} item, ${trips.length} viaggi',
      category: 'sync',
      data: {
        'houses_count': houses.length,
        'spaces_count': spaces.length,
        'luggages_count': luggages.length,
        'items_count': items.length,
        'trips_count': trips.length,
      },
    );

    final pendingPurges = <Future<void> Function()>[];

    for (final house in houses) {
      await _syncRecord(
        id: house.id,
        localUpdatedAt: house.updatedAt,
        localIsDeleted: house.isDeleted,
        sentryTraceId: house.sentryTraceId,
        toJson: () => SyncSerializers.houseToJson(house),
        fetchRemote: (trace) =>
            _remote.fetchHouseById(house.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertHouse(data, sentryTrace: trace),
        pullLocal: (remote) => _housesDao.updateHouse(
          SyncSerializers.buildHouseCompanion(remote, includeSyncFields: false),
        ),
        markSynced: (ts, localAt) =>
            _housesDao.markAsSynced(house.id, ts, localUpdatedAt: localAt),
        incrementRetry: (e) => _housesDao.incrementSyncRetry(house.id, e),
        onPurge: () =>
            pendingPurges.add(() => _housesDao.purgeRecord(house.id)),
        syncStatus: house.syncStatus,
        lastSyncedAt: house.lastSyncedAt,
        createdAt: house.createdAt,
        entity: 'house',
      );
    }

    for (final space in spaces) {
      await _syncRecord(
        id: space.id,
        localUpdatedAt: space.updatedAt,
        localIsDeleted: space.isDeleted,
        sentryTraceId: space.sentryTraceId,
        toJson: () => SyncSerializers.spaceToJson(space),
        fetchRemote: (trace) =>
            _remote.fetchSpaceById(space.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertSpace(data, sentryTrace: trace),
        pullLocal: (remote) => _spacesDao.updateSpace(
          SyncSerializers.buildSpaceCompanion(remote, includeSyncFields: false),
        ),
        markSynced: (ts, localAt) =>
            _spacesDao.markAsSynced(space.id, ts, localUpdatedAt: localAt),
        incrementRetry: (e) => _spacesDao.incrementSyncRetry(space.id, e),
        onPurge: () =>
            pendingPurges.add(() => _spacesDao.purgeRecord(space.id)),
        syncStatus: space.syncStatus,
        lastSyncedAt: space.lastSyncedAt,
        createdAt: space.createdAt,
        entity: 'space',
      );
    }

    for (final luggage in luggages) {
      await _syncRecord(
        id: luggage.id,
        localUpdatedAt: luggage.updatedAt,
        localIsDeleted: luggage.isDeleted,
        sentryTraceId: luggage.sentryTraceId,
        toJson: () => SyncSerializers.luggageToJson(luggage),
        fetchRemote: (trace) =>
            _remote.fetchLuggageById(luggage.id, sentryTrace: trace),
        upsert: (data, trace) =>
            _remote.upsertLuggage(data, sentryTrace: trace),
        pullLocal: (remote) => _luggagesDao.updateLuggage(
          SyncSerializers.buildLuggageCompanion(
            remote,
            includeSyncFields: false,
          ),
        ),
        markSynced: (ts, localAt) =>
            _luggagesDao.markAsSynced(luggage.id, ts, localUpdatedAt: localAt),
        incrementRetry: (e) => _luggagesDao.incrementSyncRetry(luggage.id, e),
        onPurge: () =>
            pendingPurges.add(() => _luggagesDao.purgeRecord(luggage.id)),
        syncStatus: luggage.syncStatus,
        lastSyncedAt: luggage.lastSyncedAt,
        createdAt: luggage.createdAt,
        entity: 'luggage',
      );
    }

    for (final item in items) {
      await _syncRecord(
        id: item.id,
        localUpdatedAt: item.updatedAt,
        localIsDeleted: item.isDeleted,
        sentryTraceId: item.sentryTraceId,
        toJson: () => SyncSerializers.itemToJson(item),
        fetchRemote: (trace) =>
            _remote.fetchItemById(item.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertItem(data, sentryTrace: trace),
        pullLocal: (remote) => _itemsDao.updateItem(
          SyncSerializers.buildItemCompanion(remote, includeSyncFields: false),
        ),
        markSynced: (ts, localAt) =>
            _itemsDao.markAsSynced(item.id, ts, localUpdatedAt: localAt),
        incrementRetry: (e) => _itemsDao.incrementSyncRetry(item.id, e),
        onPurge: () => pendingPurges.add(() => _itemsDao.purgeRecord(item.id)),
        syncStatus: item.syncStatus,
        lastSyncedAt: item.lastSyncedAt,
        createdAt: item.createdAt,
        entity: 'item',
      );
    }

    for (final trip in trips) {
      // Prefetch della checklist + luggage_ids: vengono serializzati nel
      // payload del trip su Supabase, così un nuovo device ritrova items
      // e bagagli associati senza tabelle remote dedicate.
      final tripItems = await _tripsDao.getTripItemsByTripId(trip.id);
      final tripLuggages = await _luggagesDao.getLuggagesByTrip(trip.id);
      final luggageIds = tripLuggages.map((l) => l.id).toList();
      await _syncRecord(
        id: trip.id,
        localUpdatedAt: trip.updatedAt,
        localIsDeleted: trip.isDeleted,
        sentryTraceId: trip.sentryTraceId,
        toJson: () => SyncSerializers.tripToJson(
          trip,
          items: tripItems,
          luggageIds: luggageIds,
        ),
        fetchRemote: (trace) =>
            _remote.fetchTripById(trip.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertTrip(data, sentryTrace: trace),
        pullLocal: (remote) => _pullTrip(trip.id, remote),
        markSynced: (ts, localAt) =>
            _tripsDao.markAsSynced(trip.id, ts, localUpdatedAt: localAt),
        incrementRetry: (e) => _tripsDao.incrementSyncRetry(trip.id, e),
        onPurge: () => pendingPurges.add(() => _tripsDao.purgeRecord(trip.id)),
        syncStatus: trip.syncStatus,
        lastSyncedAt: trip.lastSyncedAt,
        createdAt: trip.createdAt,
        entity: 'trip',
      );
    }

    // Purge in collected order: items/trips were added after houses,
    // so reversing gives children-first, parents-last (FK-safe).
    for (final purge in pendingPurges.reversed) {
      try {
        await purge();
      } catch (e, st) {
        debugPrint('[SyncService] Purge failed: $e');
        _monitoring.captureException(
          e,
          stackTrace: st,
          tags: const {'operation': 'processQueue_purge'},
        );
      }
    }
  }

  Future<void> _syncRecord({
    required String id,
    required DateTime localUpdatedAt,
    required bool localIsDeleted,
    required String? sentryTraceId,
    required Map<String, dynamic> Function() toJson,
    required Future<Map<String, dynamic>?> Function(String? trace) fetchRemote,
    required Future<DateTime> Function(Map<String, dynamic> data, String? trace)
    upsert,
    required Future<void> Function(Map<String, dynamic> remote) pullLocal,
    // [localUpdatedAtForWhere] è il valore di `updatedAt` presente nel DB al
    // momento in cui `markSynced` viene eseguito:
    //   - push path: invariato → usa il [localUpdatedAt] originale
    //   - pull path: `pullLocal` ha già scritto `remoteUpdatedAt` nel DB
    //     → usa quel valore come WHERE condition, altrimenti il write è no-op
    required Future<void> Function(
      DateTime serverUpdatedAt,
      DateTime localUpdatedAtForWhere,
    )
    markSynced,
    required Future<void> Function(String errorMessage) incrementRetry,
    required void Function() onPurge,
    required SyncStatus syncStatus,
    required DateTime? lastSyncedAt,
    required DateTime createdAt,
    required String entity,
  }) async {
    try {
      final transaction = Sentry.startTransaction(
        'sync.$entity',
        'sync.process',
        bindToScope: true,
      );
      if (sentryTraceId != null) {
        transaction.setData('sentryTraceId', sentryTraceId);
      }
      final traceHeader = transaction.toSentryTrace().toString();

      try {
        final remote = await fetchRemote(traceHeader);

        // Sentinella locale: il timestamp server-side dell'`updated_at`.
        // Viene popolata in TUTTI i path che fanno upsert/pull, e poi
        // applicata via `markSynced` per allineare il pivot LWW del record
        // locale al tempo di scrittura del server (immune a clock drift).
        DateTime? serverUpdatedAt;
        // Valore di `updatedAt` nel DB al momento in cui `markSynced` viene
        // eseguito. Nei push path coincide con il `localUpdatedAt` originale
        // (il DB non è stato toccato). Nel pull path `pullLocal` ha già
        // scritto `remoteUpdatedAt` → va usato quel valore come WHERE.
        DateTime localUpdatedAtForWhere = localUpdatedAt;

        if (remote == null) {
          if (syncStatus == SyncStatus.pendingCreate && !localIsDeleted) {
            debugPrint(
              '[SyncService] $entity $id: remote not found, never-synced new record -- pushing',
            );
            final data = toJson();
            serverUpdatedAt = await upsert(data, traceHeader);
          } else {
            final retentionDays = await _tombstoneConfig.getRetentionDays();
            final cutoff = DateTime.now().toUtc().subtract(
              Duration(days: retentionDays),
            );
            final referenceTime = (lastSyncedAt ?? createdAt).toUtc();

            if (referenceTime.isBefore(cutoff)) {
              debugPrint(
                '[SyncService] $entity $id: remote not found, older than $retentionDays days -- purging locally',
              );
              onPurge();
              // Niente push qui: marchiamo synced col wall clock locale —
              // il record viene purgato comunque, l'updatedAt non sarà più
              // letto da nessuno.
              await markSynced(DateTime.now().toUtc(), localUpdatedAt);
              transaction.status = const SpanStatus.ok();
              return;
            }

            debugPrint('[SyncService] $entity $id: remote not found, pushing');
            final data = toJson();
            debugPrint(
              '[SyncService] $entity $id: is_deleted=${data['is_deleted']}',
            );
            serverUpdatedAt = await upsert(data, traceHeader);
          }
        } else {
          final remoteUpdatedAt = DateTime.parse(
            remote['updated_at'] as String,
          );
          final remoteIsDeleted = remote['is_deleted'] as bool? ?? false;
          final localUtc = localUpdatedAt.toUtc();
          final remoteUtc = remoteUpdatedAt.toUtc();
          debugPrint(
            '[SyncService] $entity $id: localUtc=$localUtc remoteUtc=$remoteUtc localDel=$localIsDeleted remoteDel=$remoteIsDeleted',
          );

          final localWins =
              localUtc.isAfter(remoteUtc) ||
              (localIsDeleted && !remoteIsDeleted);

          if (localWins) {
            final data = toJson();
            debugPrint(
              '[SyncService] $entity $id: pushing (is_deleted=${data['is_deleted']})',
            );
            serverUpdatedAt = await upsert(data, traceHeader);
          } else {
            debugPrint(
              '[SyncService] $entity $id: pulling (is_deleted=$remoteIsDeleted)',
            );
            await pullLocal(remote);
            // `pullLocal` ha già scritto `updatedAt = remoteUpdatedAt` nel
            // DB locale. Per la WHERE condition di `markSynced` dobbiamo
            // usare quel valore, non il localUpdatedAt originale.
            serverUpdatedAt = remoteUpdatedAt;
            localUpdatedAtForWhere = remoteUpdatedAt;
          }
        }

        // A questo punto tutti i path che non hanno fatto early-return
        // hanno popolato serverUpdatedAt (upsert ritorna il timestamp del
        // trigger; pull lo prende da remote['updated_at']).
        await markSynced(serverUpdatedAt, localUpdatedAtForWhere);
        if (localIsDeleted) {
          onPurge();
          debugPrint('[SyncService] $entity $id: synced, purge deferred');
        } else {
          debugPrint('[SyncService] $entity $id: marked as synced');
        }
        transaction.status = const SpanStatus.ok();
      } catch (e) {
        transaction.status = const SpanStatus.internalError();
        rethrow;
      } finally {
        await transaction.finish();
      }
    } catch (e, st) {
      debugPrint('[SyncService] Failed to sync $entity $id: $e');
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: {'operation': 'syncRecord', 'entity': entity, 'id': id},
      );
      _analytics?.trackSyncFailed(
        entity: entity,
        errorType: e.runtimeType.toString(),
      );
      await incrementRetry(e.toString());
    }
  }

  // === DESERIALIZATION: Supabase JSON → Drift update ===

  Future<void> _pullTrip(String id, Map<String, dynamic> remote) async {
    await _tripsDao.updateTrip(
      SyncSerializers.buildTripCompanion(remote, includeSyncFields: false),
    );
    await _replaceTripItemsFromJson(id, remote['items']);
    await _replaceTripLuggagesFromJson(id, remote['luggage_ids']);
  }

  /// Sostituisce le associazioni trip↔luggage con [luggageIdsJson] se presente.
  ///
  /// Backward-compat: se [luggageIdsJson] è null (payload remoto legacy)
  /// lasciamo le associazioni locali intatte. Altrimenti `replaceTripLuggages`
  /// è atomico: DELETE + INSERT in transazione.
  Future<void> _replaceTripLuggagesFromJson(
    String tripId,
    dynamic luggageIdsJson,
  ) async {
    if (luggageIdsJson == null) return;
    final ids = (luggageIdsJson as List).cast<String>();
    await _luggagesDao.replaceTripLuggages(tripId, ids);
  }

  /// Sostituisce la checklist locale di [tripId] con [itemsJson], se presente.
  ///
  /// Se [itemsJson] è null (payload remoto legacy o client più vecchio che
  /// non includeva ancora il campo) lasciamo gli items locali intatti per
  /// non azzerare dati validi. Altrimenti `replaceTripItems` è atomico:
  /// DELETE + INSERT in transazione.
  Future<void> _replaceTripItemsFromJson(
    String tripId,
    dynamic itemsJson,
  ) async {
    if (itemsJson == null) return;
    final list = (itemsJson as List).cast<Map<String, dynamic>>();
    final companions = list
        .map(
          (m) => TripItemEntriesCompanion.insert(
            id: m['id'] as String,
            tripId: tripId,
            name: m['name'] as String,
            category: SyncSerializers.parseItemCategory(
              m['category'] as String,
            ),
            quantity: Value(m['quantity'] as int? ?? 1),
            originHouseId: Value(m['origin_house_id'] as String? ?? ''),
            isChecked: Value(m['is_checked'] as bool? ?? false),
          ),
        )
        .toList();
    await _tripsDao.replaceTripItems(tripId, companions);
  }

  /// Inserisce o aggiorna un item proveniente dal remoto, con fallback su
  /// `spaceId = null` se la FK sullo spazio non è risolvibile localmente.
  ///
  /// Contesto: su un device nuovo (o dopo reinstall) un item può arrivare
  /// prima che il suo space sia stato applicato localmente → FK violation.
  /// In quel caso preferiamo far "atterrare" l'item nel pool generale
  /// piuttosto che farlo sparire in silenzio. L'utente potrà riassegnarlo
  /// manualmente. Il primo fallimento viene riportato via Sentry per visibilità.
  Future<void> _persistItemWithFkFallback(
    Map<String, dynamic> r, {
    required DateTime syncedAt,
    required bool isInsert,
  }) async {
    Future<void> doOp({bool clearSpaceId = false}) async {
      final companion = SyncSerializers.buildItemCompanion(
        r,
        syncedAt: syncedAt,
        clearSpaceId: clearSpaceId,
      );
      if (isInsert) {
        await _itemsDao.insertItem(companion);
      } else {
        await _itemsDao.updateItem(companion);
      }
    }

    try {
      await doOp();
    } catch (e) {
      // Non possiamo fallback se l'item non aveva uno spaceId remoto:
      // il problema è altrove (es. houseId FK) e va rilanciato.
      if (r['space_id'] == null) rethrow;
      debugPrint(
        '[SyncService] item ${r['id']}: FK on spaceId=${r['space_id']}, '
        'retry with null',
      );
      await doOp(clearSpaceId: true);
      _monitoring.captureException(
        e,
        tags: {
          'reason': 'item_space_fk_fallback',
          'item_id': r['id'] as String,
          'remote_space_id': r['space_id'] as String,
        },
      );
    }
  }
}
