import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../model/trip_model.dart' as model;
import 'trip_repository.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../core/database/converters/location_type_converter.dart';
import '../../../core/database/database.dart';
import '../../../core/database/daos/trips_dao.dart';
import '../../../core/database/daos/luggages_dao.dart';
import '../../../core/database/services/database_service.dart';
import '../../items/model/item_model.dart';
import '../../luggages/model/luggage_model.dart';
import '../../../core/database/converters/luggage_size_converter.dart';

/// Implementazione del repository Trip usando Drift (SQLite).
/// 
/// Fornisce operazioni robuste con:
/// - Retry automatico per operazioni fallite
/// - Transazioni atomiche per viaggio + items + luggages
/// - Logging delle operazioni
class DriftTripRepository implements TripRepository {
  final TripsDao _dao;
  final LuggagesDao _luggagesDao;
  final DatabaseService _dbService;

  DriftTripRepository(this._dao, this._luggagesDao, this._dbService);

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> addTrip(model.TripModel trip) async {
    // Usa transazione atomica per garantire che viaggio, items e luggages
    // siano salvati insieme o non salvati affatto
    final result = await _dbService.executeAtomicWithRetry(
      () async {
        // Inserisci il viaggio
        await _dao.insertTrip(_toTripCompanion(trip));
        
        // Inserisci gli oggetti del viaggio
        if (trip.items.isNotEmpty) {
          final tripItems = trip.items.map(
            (item) => _toTripItemCompanion(trip.id, item),
          ).toList();
          await _dao.insertMultipleTripItems(tripItems);
        }
        
        // Inserisci le associazioni con i bagagli (junction table)
        if (trip.luggages.isNotEmpty) {
          final luggageIds = trip.luggages.map((l) => l.id).toList();
          await _luggagesDao.replaceTripLuggages(trip.id, luggageIds);
        }
      },
      operationName: 'addTrip(${trip.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiungere il viaggio: ${result.error}');
    }
    
    debugPrint('[TripRepo] Viaggio aggiunto: ${trip.name} con ${trip.items.length} items e ${trip.luggages.length} bagagli');
  }

  @override
  Future<model.TripModel> getTripById(String id) async {
    final result = await _dbService.executeWithRetry(
      () async {
        // Usa il metodo ottimizzato del DAO con queries parallele
        final tripWithRelations = await _dao.getTripByIdWithRelations(id);
        if (tripWithRelations == null) return null;
        
        return _toModel(
          tripWithRelations.trip,
          tripWithRelations.items,
          tripWithRelations.luggages,
        );
      },
      operationName: 'getTripById($id)',
    );
    
    if (!result.success || result.data == null) {
      throw StateError('Viaggio con id $id non trovato');
    }
    
    return result.data!;
  }

  @override
  Future<List<model.TripModel>> getAllTrips() async {
    final result = await _dbService.executeWithRetry(
      () async {
        // ═══════════════════════════════════════════════════════════
        // OPTIMIZED BATCH LOADING - Risolve N+1 Query Problem
        // ═══════════════════════════════════════════════════════════
        // 
        // Invece di:
        //   1 query per getAllTrips() +
        //   N queries per getTripItemsByTripId() +
        //   N queries per getLuggagesByTrip()
        //   = 1 + 2N queries totali 😱
        // 
        // Usiamo:
        //   1 query per getAllTrips() +
        //   1 query per tutti i trip_items (grouped) +
        //   1 query per tutti i luggages (grouped)
        //   = 3 queries totali 🚀
        // ═══════════════════════════════════════════════════════════
        
        // Query 1: Load all trips
        final trips = await _dao.getAllTrips();
        
        // Query 2: Load all trip items for all trips (batch)
        final itemsGrouped = await _dao.getAllTripItemsGrouped();
        
        // Query 3: Load all luggages for all trips (batch)
        final luggagesGrouped = await _dao.getAllTripLuggagesGrouped();
        
        // In-memory matching (O(N) - molto veloce)
        final List<model.TripModel> models = [];
        for (final trip in trips) {
          try {
            final tripItems = itemsGrouped[trip.id] ?? [];
            final luggages = luggagesGrouped[trip.id] ?? [];
            models.add(_toModel(trip, tripItems, luggages));
          } catch (e) {
            // Se un viaggio ha problemi, logga ma continua con gli altri
            debugPrint('[TripRepo] Errore mappando viaggio ${trip.id}: $e');
            models.add(_toModel(trip, [], []));
          }
        }
        
        return models;
      },
      operationName: 'getAllTrips',
    );
    
    if (!result.success) {
      debugPrint('[TripRepo] Errore caricando viaggi: ${result.error}');
      return [];
    }
    
    return result.data!;
  }

  @override
  Future<bool> deleteTrip(String id) async {
    // I trip_items vengono eliminati automaticamente grazie a ON DELETE CASCADE
    final result = await _dbService.executeWithRetry(
      () => _dao.deleteTrip(id),
      operationName: 'deleteTrip($id)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      debugPrint('[TripRepo] Errore eliminando viaggio: ${result.error}');
      return false;
    }
    
    debugPrint('[TripRepo] Viaggio eliminato: $id');
    return result.data! > 0;
  }

  @override
  Future<String> duplicateTrip(String originalTripId) async {
    final newTripId = const Uuid().v4();
    
    // Usa transazione atomica per copiare viaggio + tutti gli items
    final result = await _dbService.executeAtomicWithRetry(
      () => _dao.duplicateTrip(originalTripId, newTripId),
      operationName: 'duplicateTrip($originalTripId)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile duplicare il viaggio: ${result.error}');
    }
    
    debugPrint('[TripRepo] Viaggio duplicato: $originalTripId -> $newTripId');
    return newTripId;
  }

  @override
  Future<void> updateTrip(model.TripModel trip) async {
    // Usa transazione atomica per garantire consistenza
    final result = await _dbService.executeAtomicWithRetry(
      () async {
        // Aggiorna il viaggio
        await _dao.updateTrip(_toTripCompanion(trip));
        
        // Sostituisci tutti gli oggetti del viaggio
        final tripItems = trip.items.map(
          (item) => _toTripItemCompanion(trip.id, item),
        ).toList();
        await _dao.replaceTripItems(trip.id, tripItems);
        
        // Sostituisci tutte le associazioni con i bagagli
        final luggageIds = trip.luggages.map((l) => l.id).toList();
        await _luggagesDao.replaceTripLuggages(trip.id, luggageIds);
      },
      operationName: 'updateTrip(${trip.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare il viaggio: ${result.error}');
    }
    
    debugPrint('[TripRepo] Viaggio aggiornato: ${trip.name} con ${trip.items.length} items e ${trip.luggages.length} bagagli');
  }

  /// Stream reattivo di tutti i viaggi.
  /// 
  /// Usa batch loading ottimizzato per evitare N+1 queries.
  Stream<List<model.TripModel>> watchAllTrips() {
    return _dao.watchAllTrips().asyncMap((trips) async {
      // Batch load di tutti i dati relazionali (2 queries totali)
      final itemsGrouped = await _dao.getAllTripItemsGrouped();
      final luggagesGrouped = await _dao.getAllTripLuggagesGrouped();
      
      // In-memory matching
      final List<model.TripModel> models = [];
      for (final trip in trips) {
        try {
          final tripItems = itemsGrouped[trip.id] ?? [];
          final luggages = luggagesGrouped[trip.id] ?? [];
          models.add(_toModel(trip, tripItems, luggages));
        } catch (e) {
          debugPrint('[TripRepo] Errore nello stream per viaggio ${trip.id}: $e');
          models.add(_toModel(trip, [], []));
        }
      }
      return models;
    });
  }

  // === Conversioni ===

  model.TripModel _toModel(
    Trip trip,
    List<TripItemEntry> tripItems,
    List<Luggage> luggages,
  ) {
    LocationSuggestionModel? destinationLocation;
    if (trip.locationDisplayName != null && trip.locationDisplayName!.isNotEmpty) {
      destinationLocation = LocationSuggestionModel(
        placeId: trip.locationPlaceId ?? '',
        displayName: trip.locationDisplayName!,
        name: trip.locationName,
        city: trip.locationCity,
        state: trip.locationState,
        country: trip.locationCountry,
        locationType: LocationTypeConverter.fromDatabase(trip.locationType),
        lat: trip.locationLat,
        lon: trip.locationLon,
      );
    }

    return model.TripModel(
      id: trip.id,
      name: trip.name,
      description: trip.description,
      items: tripItems.map(_tripItemToModel).toList(),
      departureDateTime: trip.departureDateTime,
      returnDateTime: trip.returnDateTime,
      destinationHouseId: trip.destinationHouseId,
      destinationLocation: destinationLocation,
      luggages: luggages.map(_luggageToModel).toList(),
      isSaved: trip.isSaved,
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
    );
  }

  model.TripItem _tripItemToModel(TripItemEntry entry) {
    return model.TripItem(
      id: entry.id,
      name: entry.name,
      category: _parseCategory(entry.category),
      quantity: entry.quantity,
      originHouseId: entry.originHouseId,
      isChecked: entry.isChecked,
    );
  }

  LuggageModel _luggageToModel(Luggage luggage) {
    return LuggageModel(
      id: luggage.id,
      houseId: luggage.houseId,
      name: luggage.name,
      sizeType: const LuggageSizeConverter().fromSql(luggage.sizeType),
      volumeLiters: luggage.volumeLiters,
      createdAt: luggage.createdAt,
      updatedAt: luggage.updatedAt,
    );
  }

  TripsCompanion _toTripCompanion(model.TripModel trip) {
    final location = trip.destinationLocation;
    
    return TripsCompanion(
      id: Value(trip.id),
      name: Value(trip.name),
      description: Value(trip.description),
      departureDateTime: Value(trip.departureDateTime),
      returnDateTime: Value(trip.returnDateTime),
      destinationHouseId: Value(trip.destinationHouseId),
      locationPlaceId: Value(location?.placeId),
      locationDisplayName: Value(location?.displayName),
      locationName: Value(location?.name),
      locationCity: Value(location?.city),
      locationState: Value(location?.state),
      locationCountry: Value(location?.country),
      locationType: Value(location != null 
          ? LocationTypeConverter.toDatabase(location.locationType)
          : null),
      locationLat: Value(location?.lat),
      locationLon: Value(location?.lon),
      isSaved: Value(trip.isSaved),
      createdAt: Value(trip.createdAt),
      updatedAt: Value(trip.updatedAt),
    );
  }

  TripItemEntriesCompanion _toTripItemCompanion(String tripId, model.TripItem item) {
    return TripItemEntriesCompanion(
      id: Value(item.id),
      tripId: Value(tripId),
      name: Value(item.name),
      category: Value(item.category.name),
      quantity: Value(item.quantity),
      originHouseId: Value(item.originHouseId),
      isChecked: Value(item.isChecked),
    );
  }

  /// Converte una stringa in ItemCategory
  /// Supporta diversi formati per retrocompatibilità:
  /// - "vestiti" (enum.name)
  /// - "Vestiti" (displayName)
  /// - case-insensitive
  ItemCategory _parseCategory(String categoryString) {
    if (categoryString.isEmpty) {
      return ItemCategory.varie;
    }
    
    try {
      final normalized = categoryString.toLowerCase().trim();
      
      // Prova prima con match esatto su .name
      for (final cat in ItemCategory.values) {
        if (cat.name.toLowerCase() == normalized) {
          return cat;
        }
      }
      
      // Prova con displayName (case-insensitive)
      for (final cat in ItemCategory.values) {
        if (cat.displayName.toLowerCase() == normalized) {
          return cat;
        }
      }
      
      debugPrint('[TripRepo] Categoria non valida: "$categoryString", usando "varie"');
      return ItemCategory.varie;
    } catch (e) {
      debugPrint('[TripRepo] Errore parsing categoria "$categoryString": $e, usando "varie"');
      return ItemCategory.varie;
    }
  }
}
