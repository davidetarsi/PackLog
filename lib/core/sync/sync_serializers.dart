import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/houses/model/house_model.dart';
import '../../features/items/model/item_model.dart';
import '../../features/luggages/model/luggage_model.dart';
import '../../shared/model/location_type.dart';
import '../database/database.dart';
import '../database/tables/mixins/syncable_table.dart';

/// Fallback non localizzato per il push di una casa senza nome, città né
/// località — solo per soddisfare `houses_name_check` (`char_length(name) >= 1`)
/// su Supabase. Mai mostrato in UI: lì [HouseModel.displayName] ricalcola
/// sempre un fallback localizzato fresco, indipendentemente da questo valore.
const String _unnamedHouseSyncFallback = 'Unnamed house';

/// Namespace statico per le funzioni pure di serializzazione e deserializzazione
/// tra i JSON di Supabase e i Companion di Drift.
///
/// `abstract` vieta l'istanziazione, `final` vieta l'estensione:
/// questa classe è un namespace, non un tipo da usare come tale.
abstract final class SyncSerializers {
  // ─── PARSE HELPERS ────────────────────────────────────────────────────────

  static LocationType? parseLocationType(dynamic value) {
    if (value == null) return null;
    return LocationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LocationType.other,
    );
  }

  static ItemCategory parseItemCategory(String value) {
    return ItemCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemCategory.varie,
    );
  }

  static LuggageSize parseLuggageSize(dynamic value) {
    if (value == null) return LuggageSize.cabinBaggage;
    return LuggageSize.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LuggageSize.cabinBaggage,
    );
  }

  static DateTime? parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  // ─── COMPANION BUILDERS (remote JSON → Drift companion) ───────────────────

  /// Costruisce un [HousesCompanion] da un payload JSON remoto.
  ///
  /// [syncedAt] è richiesto solo quando [includeSyncFields] è true (default).
  /// Con [includeSyncFields] false i campi sync vengono omessi (Value.absent):
  /// usato nel pull path di processQueue dove [markXAsSynced] li scrive dopo.
  static HousesCompanion buildHouseCompanion(
    Map<String, dynamic> r, {
    DateTime? syncedAt,
    bool includeSyncFields = true,
  }) {
    assert(
      !includeSyncFields || syncedAt != null,
      'syncedAt è richiesto quando includeSyncFields=true',
    );
    return HousesCompanion(
      id: Value(r['id'] as String),
      userId: Value(r['user_id'] as String?),
      name: Value(r['name'] as String),
      description: Value(r['description'] as String?),
      locationPlaceId: Value(r['location_place_id'] as String?),
      locationDisplayName: Value(r['location_display_name'] as String?),
      locationName: Value(r['location_name'] as String?),
      locationCity: Value(r['location_city'] as String?),
      locationState: Value(r['location_state'] as String?),
      locationCountry: Value(r['location_country'] as String?),
      locationType: Value(parseLocationType(r['location_type'])),
      locationLat: Value(r['location_lat'] as double?),
      locationLon: Value(r['location_lon'] as double?),
      iconName: Value(r['icon_name'] as String? ?? 'home'),
      isPrimary: Value(r['is_primary'] as bool? ?? false),
      createdAt: Value(DateTime.parse(r['created_at'] as String)),
      updatedAt: Value(DateTime.parse(r['updated_at'] as String)),
      isDeleted: Value(r['is_deleted'] as bool? ?? false),
      lastSyncedAt: includeSyncFields ? Value(syncedAt!) : const Value.absent(),
      syncStatus: includeSyncFields
          ? const Value(SyncStatus.synced)
          : const Value.absent(),
      syncRetryCount: includeSyncFields ? const Value(0) : const Value.absent(),
      lastSyncError: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      nextSyncAttemptAt: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      sentryTraceId: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
    );
  }

  static ItemsCompanion buildItemCompanion(
    Map<String, dynamic> r, {
    DateTime? syncedAt,
    bool clearSpaceId = false,
    bool includeSyncFields = true,
  }) {
    assert(
      !includeSyncFields || syncedAt != null,
      'syncedAt è richiesto quando includeSyncFields=true',
    );
    return ItemsCompanion(
      id: Value(r['id'] as String),
      userId: Value(r['user_id'] as String?),
      houseId: Value(r['house_id'] as String),
      name: Value(r['name'] as String),
      category: Value(parseItemCategory(r['category'] as String)),
      description: Value(r['description'] as String?),
      quantity: Value(r['quantity'] as int?),
      spaceId: clearSpaceId
          ? const Value(null)
          : Value(r['space_id'] as String?),
      aiMetadata: Value(r['ai_metadata'] as String?),
      createdAt: Value(DateTime.parse(r['created_at'] as String)),
      updatedAt: Value(DateTime.parse(r['updated_at'] as String)),
      isDeleted: Value(r['is_deleted'] as bool? ?? false),
      lastSyncedAt: includeSyncFields ? Value(syncedAt!) : const Value.absent(),
      syncStatus: includeSyncFields
          ? const Value(SyncStatus.synced)
          : const Value.absent(),
      syncRetryCount: includeSyncFields ? const Value(0) : const Value.absent(),
      lastSyncError: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      nextSyncAttemptAt: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      sentryTraceId: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
    );
  }

  static SpacesCompanion buildSpaceCompanion(
    Map<String, dynamic> r, {
    DateTime? syncedAt,
    bool includeSyncFields = true,
  }) {
    assert(
      !includeSyncFields || syncedAt != null,
      'syncedAt è richiesto quando includeSyncFields=true',
    );
    return SpacesCompanion(
      id: Value(r['id'] as String),
      userId: Value(r['user_id'] as String?),
      houseId: Value(r['house_id'] as String),
      name: Value(r['name'] as String),
      iconName: Value(r['icon_name'] as String?),
      createdAt: Value(DateTime.parse(r['created_at'] as String)),
      updatedAt: Value(DateTime.parse(r['updated_at'] as String)),
      isDeleted: Value(r['is_deleted'] as bool? ?? false),
      lastSyncedAt: includeSyncFields ? Value(syncedAt!) : const Value.absent(),
      syncStatus: includeSyncFields
          ? const Value(SyncStatus.synced)
          : const Value.absent(),
      syncRetryCount: includeSyncFields ? const Value(0) : const Value.absent(),
      lastSyncError: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      nextSyncAttemptAt: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      sentryTraceId: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
    );
  }

  static LuggagesCompanion buildLuggageCompanion(
    Map<String, dynamic> r, {
    DateTime? syncedAt,
    bool includeSyncFields = true,
  }) {
    assert(
      !includeSyncFields || syncedAt != null,
      'syncedAt è richiesto quando includeSyncFields=true',
    );
    return LuggagesCompanion(
      id: Value(r['id'] as String),
      userId: Value(r['user_id'] as String?),
      houseId: Value(r['house_id'] as String),
      name: Value(r['name'] as String),
      sizeType: Value(parseLuggageSize(r['size_type'])),
      volumeLiters: Value(r['volume_liters'] as int?),
      createdAt: Value(DateTime.parse(r['created_at'] as String)),
      updatedAt: Value(DateTime.parse(r['updated_at'] as String)),
      isDeleted: Value(r['is_deleted'] as bool? ?? false),
      lastSyncedAt: includeSyncFields ? Value(syncedAt!) : const Value.absent(),
      syncStatus: includeSyncFields
          ? const Value(SyncStatus.synced)
          : const Value.absent(),
      syncRetryCount: includeSyncFields ? const Value(0) : const Value.absent(),
      lastSyncError: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      nextSyncAttemptAt: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      sentryTraceId: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
    );
  }

  static TripsCompanion buildTripCompanion(
    Map<String, dynamic> r, {
    DateTime? syncedAt,
    bool includeSyncFields = true,
  }) {
    assert(
      !includeSyncFields || syncedAt != null,
      'syncedAt è richiesto quando includeSyncFields=true',
    );
    return TripsCompanion(
      id: Value(r['id'] as String),
      userId: Value(r['user_id'] as String?),
      name: Value(r['name'] as String),
      description: Value(r['description'] as String?),
      departureDateTime: Value(parseNullableDateTime(r['departure_date_time'])),
      returnDateTime: Value(parseNullableDateTime(r['return_date_time'])),
      destinationHouseId: Value(r['destination_house_id'] as String?),
      locationPlaceId: Value(r['location_place_id'] as String?),
      locationDisplayName: Value(r['location_display_name'] as String?),
      locationName: Value(r['location_name'] as String?),
      locationCity: Value(r['location_city'] as String?),
      locationState: Value(r['location_state'] as String?),
      locationCountry: Value(r['location_country'] as String?),
      locationType: Value(parseLocationType(r['location_type'])),
      locationLat: Value(r['location_lat'] as double?),
      locationLon: Value(r['location_lon'] as double?),
      isSaved: Value(r['is_saved'] as bool? ?? false),
      // `null` = nessuna informazione (riga anteriore allo schema 10) → non
      // toccare il locale. `[]` = l'utente ha rimosso le tappe → azzerare.
      legs: r['legs'] == null
          ? const Value.absent()
          : Value(jsonEncode(r['legs'])),
      createdAt: Value(DateTime.parse(r['created_at'] as String)),
      updatedAt: Value(DateTime.parse(r['updated_at'] as String)),
      isDeleted: Value(r['is_deleted'] as bool? ?? false),
      lastSyncedAt: includeSyncFields ? Value(syncedAt!) : const Value.absent(),
      syncStatus: includeSyncFields
          ? const Value(SyncStatus.synced)
          : const Value.absent(),
      syncRetryCount: includeSyncFields ? const Value(0) : const Value.absent(),
      lastSyncError: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      nextSyncAttemptAt: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
      sentryTraceId: includeSyncFields
          ? const Value(null)
          : const Value.absent(),
    );
  }

  // ─── SERIALIZERS (Drift → Supabase JSON) ──────────────────────────────────

  static Map<String, dynamic> houseToJson(House house) {
    return {
      'id': house.id,
      'user_id': house.userId,
      // Il push non manda mai una stringa vuota: `houses_name_check` su
      // Supabase richiede char_length(name) >= 1, ma localmente il nome è
      // opzionale (city/location come fallback in UI, vedi HouseModel.
      // displayName). Stessa priorità, stessa funzione condivisa.
      'name': resolveHouseDisplayName(
        name: house.name,
        cityName: house.locationCity,
        locationDisplayName: house.locationDisplayName,
        fallback: _unnamedHouseSyncFallback,
      ),
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

  static Map<String, dynamic> itemToJson(Item item) {
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
      'ai_metadata': item.aiMetadata,
    };
  }

  static Map<String, dynamic> spaceToJson(Space space) {
    return {
      'id': space.id,
      'user_id': space.userId,
      'house_id': space.houseId,
      'name': space.name,
      'icon_name': space.iconName,
      'created_at': space.createdAt.toUtc().toIso8601String(),
      'updated_at': space.updatedAt.toUtc().toIso8601String(),
      'is_deleted': space.isDeleted,
    };
  }

  static Map<String, dynamic> luggageToJson(Luggage luggage) {
    return {
      'id': luggage.id,
      'user_id': luggage.userId,
      'house_id': luggage.houseId,
      'name': luggage.name,
      'size_type': luggage.sizeType.name,
      'volume_liters': luggage.volumeLiters,
      'created_at': luggage.createdAt.toUtc().toIso8601String(),
      'updated_at': luggage.updatedAt.toUtc().toIso8601String(),
      'is_deleted': luggage.isDeleted,
    };
  }

  /// Serializza il trip, la sua checklist (snapshot immutabile) e gli id dei
  /// bagagli associati in un unico payload.
  ///
  /// Items e luggage_ids sono parte del trip per Supabase: niente tabelle remote
  /// dedicate, niente N+1 sul pull. Per i luggages serializziamo solo gli id
  /// perché le entità reali vivono nella tabella `luggages` (sync separato).
  static Map<String, dynamic> tripToJson(
    Trip trip, {
    required List<TripItemEntry> items,
    required List<String> luggageIds,
  }) {
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
      'items': items
          .map(
            (e) => {
              'id': e.id,
              'name': e.name,
              'category': e.category.name,
              'quantity': e.quantity,
              'origin_house_id': e.originHouseId,
              'is_checked': e.isChecked,
            },
          )
          .toList(),
      'luggage_ids': luggageIds,
      // Sempre una lista: `null` significherebbe "nessuna informazione" e la
      // rimozione delle tappe non si propagherebbe mai.
      'legs': trip.legs == null ? const <dynamic>[] : jsonDecode(trip.legs!),
    };
  }
}
