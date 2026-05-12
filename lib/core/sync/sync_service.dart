import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../features/items/model/item_model.dart';
import '../../shared/model/location_type.dart';
import '../database/daos/houses_dao.dart';
import '../database/daos/items_dao.dart';
import '../database/daos/trips_dao.dart';
import '../database/database.dart';
import '../database/tables/mixins/syncable_table.dart';
import '../monitoring/monitoring_service.dart';
import 'supabase_repository.dart';
import 'tombstone_config_service.dart';

class SyncService {
  final HousesDao _housesDao;
  final ItemsDao _itemsDao;
  final TripsDao _tripsDao;
  final SupabaseRepository _remote;
  final AppMonitoringService _monitoring;
  final TombstoneConfigService _tombstoneConfig;

  SyncService({
    required HousesDao housesDao,
    required ItemsDao itemsDao,
    required TripsDao tripsDao,
    required SupabaseRepository remote,
    required AppMonitoringService monitoring,
    required TombstoneConfigService tombstoneConfig,
  })  : _housesDao = housesDao,
        _itemsDao = itemsDao,
        _tripsDao = tripsDao,
        _remote = remote,
        _monitoring = monitoring,
        _tombstoneConfig = tombstoneConfig;

  /// One-time recovery: re-marks soft-deleted records that were incorrectly
  /// left as "synced" (due to a prior timezone bug that caused pulls instead
  /// of pushes). After this runs, processQueue will pick them up.
  bool _recoveryDone = false;
  Future<void> _recoverStaleSoftDeletes() async {
    if (_recoveryDone) return;
    _recoveryDone = true;
    final count = await _housesDao.markDeletedAsPendingSync() +
        await _itemsDao.markDeletedAsPendingSync() +
        await _tripsDao.markDeletedAsPendingSync();
    if (count > 0) {
      debugPrint('[SyncService] Recovery: $count stale soft-deleted records re-queued');
    }
  }

  /// FK-safe order: houses → items → trips (create/update).
  /// Purge order is reversed: items/trips first, houses last (FK safety).
  Future<void> processQueue() async {
    await _recoverStaleSoftDeletes();
    final houses = await _housesDao.getPendingSyncHouses();
    final items = await _itemsDao.getPendingSyncItems();
    final trips = await _tripsDao.getPendingSyncTrips();

    _monitoring.logBreadcrumb(
      'Avvio batch sync: ${houses.length} case, ${items.length} item, ${trips.length} viaggi',
      category: 'sync',
      data: {
        'houses_count': houses.length,
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
        toJson: () => _houseToJson(house),
        fetchRemote: (trace) => _remote.fetchHouseById(house.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertHouse(data, sentryTrace: trace),
        pullLocal: (remote) => _pullHouse(house.id, remote),
        markSynced: (ts) => _housesDao.markHouseAsSynced(house.id, ts),
        incrementRetry: (e) => _housesDao.incrementSyncRetry(house.id, e),
        onPurge: () => pendingPurges.add(() => _housesDao.purgeHouse(house.id)),
        syncStatus: house.syncStatus,
        lastSyncedAt: house.lastSyncedAt,
        createdAt: house.createdAt,
        entity: 'house',
      );
    }

    for (final item in items) {
      await _syncRecord(
        id: item.id,
        localUpdatedAt: item.updatedAt,
        localIsDeleted: item.isDeleted,
        sentryTraceId: item.sentryTraceId,
        toJson: () => _itemToJson(item),
        fetchRemote: (trace) => _remote.fetchItemById(item.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertItem(data, sentryTrace: trace),
        pullLocal: (remote) => _pullItem(item.id, remote),
        markSynced: (ts) => _itemsDao.markItemAsSynced(item.id, ts),
        incrementRetry: (e) => _itemsDao.incrementSyncRetry(item.id, e),
        onPurge: () => pendingPurges.add(() => _itemsDao.purgeItem(item.id)),
        syncStatus: item.syncStatus,
        lastSyncedAt: item.lastSyncedAt,
        createdAt: item.createdAt,
        entity: 'item',
      );
    }

    for (final trip in trips) {
      await _syncRecord(
        id: trip.id,
        localUpdatedAt: trip.updatedAt,
        localIsDeleted: trip.isDeleted,
        sentryTraceId: trip.sentryTraceId,
        toJson: () => _tripToJson(trip),
        fetchRemote: (trace) => _remote.fetchTripById(trip.id, sentryTrace: trace),
        upsert: (data, trace) => _remote.upsertTrip(data, sentryTrace: trace),
        pullLocal: (remote) => _pullTrip(trip.id, remote),
        markSynced: (ts) => _tripsDao.markTripAsSynced(trip.id, ts),
        incrementRetry: (e) => _tripsDao.incrementSyncRetry(trip.id, e),
        onPurge: () => pendingPurges.add(() => _tripsDao.purgeTrip(trip.id)),
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
        Sentry.captureException(e, stackTrace: st);
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
    required Future<void> Function(Map<String, dynamic> data, String? trace) upsert,
    required Future<void> Function(Map<String, dynamic> remote) pullLocal,
    required Future<void> Function(DateTime serverUpdatedAt) markSynced,
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

        if (remote == null) {
          if (syncStatus == SyncStatus.pendingCreate && !localIsDeleted) {
            debugPrint('[SyncService] $entity $id: remote not found, never-synced new record -- pushing');
            final data = toJson();
            await upsert(data, traceHeader);
          } else {
            final retentionDays = await _tombstoneConfig.getRetentionDays();
            final cutoff = DateTime.now().toUtc().subtract(Duration(days: retentionDays));
            final referenceTime = (lastSyncedAt ?? createdAt).toUtc();

            if (referenceTime.isBefore(cutoff)) {
              debugPrint('[SyncService] $entity $id: remote not found, older than $retentionDays days -- purging locally');
              onPurge();
              await markSynced(DateTime.now());
              transaction.status = const SpanStatus.ok();
              return;
            }

            debugPrint('[SyncService] $entity $id: remote not found, pushing');
            final data = toJson();
            debugPrint('[SyncService] $entity $id: is_deleted=${data['is_deleted']}');
            await upsert(data, traceHeader);
          }
        } else {
          final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
          final remoteIsDeleted = remote['is_deleted'] as bool? ?? false;
          final localUtc = localUpdatedAt.toUtc();
          final remoteUtc = remoteUpdatedAt.toUtc();
          debugPrint('[SyncService] $entity $id: localUtc=$localUtc remoteUtc=$remoteUtc localDel=$localIsDeleted remoteDel=$remoteIsDeleted');

          final localWins = localUtc.isAfter(remoteUtc) ||
              (localIsDeleted && !remoteIsDeleted);

          if (localWins) {
            final data = toJson();
            debugPrint('[SyncService] $entity $id: pushing (is_deleted=${data['is_deleted']})');
            await upsert(data, traceHeader);
          } else {
            debugPrint('[SyncService] $entity $id: pulling (is_deleted=$remoteIsDeleted)');
            await pullLocal(remote);
          }
        }

        final now = DateTime.now();
        await markSynced(now);
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
      Sentry.captureException(e, stackTrace: st);
      await incrementRetry(e.toString());
    }
  }

  // === SERIALIZATION: Drift → Supabase JSON ===

  Map<String, dynamic> _houseToJson(House house) {
    return {
      'id': house.id,
      'user_id': house.userId,
      'name': house.name,
      'description': house.description,
      'location_place_id': house.locationPlaceId,
      'location_display_name': house.locationDisplayName,
      'location_name': house.locationName,
      'location_city': house.locationCity,
      'location_state': house.locationState,
      'location_country': house.locationCountry,
      'location_type': house.locationType?.name,
      'location_lat': house.locationLat,
      'location_lon': house.locationLon,
      'icon_name': house.iconName,
      'is_primary': house.isPrimary,
      'created_at': house.createdAt.toUtc().toIso8601String(),
      'updated_at': house.updatedAt.toUtc().toIso8601String(),
      'is_deleted': house.isDeleted,
    };
  }

  Map<String, dynamic> _itemToJson(Item item) {
    return {
      'id': item.id,
      'user_id': item.userId,
      'house_id': item.houseId,
      'name': item.name,
      'category': item.category.name,
      'description': item.description,
      'quantity': item.quantity,
      'space_id': item.spaceId,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'updated_at': item.updatedAt.toUtc().toIso8601String(),
      'is_deleted': item.isDeleted,
    };
  }

  Map<String, dynamic> _tripToJson(Trip trip) {
    return {
      'id': trip.id,
      'user_id': trip.userId,
      'name': trip.name,
      'description': trip.description,
      'departure_date_time': trip.departureDateTime?.toUtc().toIso8601String(),
      'return_date_time': trip.returnDateTime?.toUtc().toIso8601String(),
      'destination_house_id': trip.destinationHouseId,
      'location_place_id': trip.locationPlaceId,
      'location_display_name': trip.locationDisplayName,
      'location_name': trip.locationName,
      'location_city': trip.locationCity,
      'location_state': trip.locationState,
      'location_country': trip.locationCountry,
      'location_type': trip.locationType?.name,
      'location_lat': trip.locationLat,
      'location_lon': trip.locationLon,
      'is_saved': trip.isSaved,
      'created_at': trip.createdAt.toUtc().toIso8601String(),
      'updated_at': trip.updatedAt.toUtc().toIso8601String(),
      'is_deleted': trip.isDeleted,
    };
  }

  // === DESERIALIZATION: Supabase JSON → Drift update ===

  Future<void> _pullHouse(String id, Map<String, dynamic> remote) async {
    await _housesDao.updateHouse(
      HousesCompanion(
        id: Value(id),
        name: Value(remote['name'] as String),
        description: Value(remote['description'] as String?),
        locationPlaceId: Value(remote['location_place_id'] as String?),
        locationDisplayName: Value(remote['location_display_name'] as String?),
        locationName: Value(remote['location_name'] as String?),
        locationCity: Value(remote['location_city'] as String?),
        locationState: Value(remote['location_state'] as String?),
        locationCountry: Value(remote['location_country'] as String?),
        locationType: Value(_parseLocationType(remote['location_type'])),
        locationLat: Value(remote['location_lat'] as double?),
        locationLon: Value(remote['location_lon'] as double?),
        iconName: Value(remote['icon_name'] as String? ?? 'home'),
        isPrimary: Value(remote['is_primary'] as bool? ?? false),
        createdAt: Value(DateTime.parse(remote['created_at'] as String)),
        updatedAt: Value(DateTime.parse(remote['updated_at'] as String)),
        isDeleted: Value(remote['is_deleted'] as bool? ?? false),
      ),
    );
  }

  Future<void> _pullItem(String id, Map<String, dynamic> remote) async {
    await _itemsDao.updateItem(
      ItemsCompanion(
        id: Value(id),
        houseId: Value(remote['house_id'] as String),
        name: Value(remote['name'] as String),
        category: Value(_parseItemCategory(remote['category'] as String)),
        description: Value(remote['description'] as String?),
        quantity: Value(remote['quantity'] as int?),
        spaceId: Value(remote['space_id'] as String?),
        createdAt: Value(DateTime.parse(remote['created_at'] as String)),
        updatedAt: Value(DateTime.parse(remote['updated_at'] as String)),
        isDeleted: Value(remote['is_deleted'] as bool? ?? false),
      ),
    );
  }

  Future<void> _pullTrip(String id, Map<String, dynamic> remote) async {
    await _tripsDao.updateTrip(
      TripsCompanion(
        id: Value(id),
        name: Value(remote['name'] as String),
        description: Value(remote['description'] as String?),
        departureDateTime: Value(_parseNullableDateTime(remote['departure_date_time'])),
        returnDateTime: Value(_parseNullableDateTime(remote['return_date_time'])),
        destinationHouseId: Value(remote['destination_house_id'] as String?),
        locationPlaceId: Value(remote['location_place_id'] as String?),
        locationDisplayName: Value(remote['location_display_name'] as String?),
        locationName: Value(remote['location_name'] as String?),
        locationCity: Value(remote['location_city'] as String?),
        locationState: Value(remote['location_state'] as String?),
        locationCountry: Value(remote['location_country'] as String?),
        locationType: Value(_parseLocationType(remote['location_type'])),
        locationLat: Value(remote['location_lat'] as double?),
        locationLon: Value(remote['location_lon'] as double?),
        isSaved: Value(remote['is_saved'] as bool? ?? false),
        createdAt: Value(DateTime.parse(remote['created_at'] as String)),
        updatedAt: Value(DateTime.parse(remote['updated_at'] as String)),
        isDeleted: Value(remote['is_deleted'] as bool? ?? false),
      ),
    );
  }

  // === PARSE HELPERS ===

  LocationType? _parseLocationType(dynamic value) {
    if (value == null) return null;
    return LocationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LocationType.other,
    );
  }

  ItemCategory _parseItemCategory(String value) {
    return ItemCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemCategory.varie,
    );
  }

  DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }
}
