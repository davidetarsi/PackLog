import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../model/trip_model.dart' as model;
import 'trip_repository.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../core/database/converters/location_type_converter.dart';
import '../../../core/database/database.dart';
import '../../../core/database/daos/trips_dao.dart';
import '../../../core/database/services/database_service.dart';

/// Implementazione del repository Trip usando Drift (SQLite).
/// 
/// Fornisce operazioni robuste con:
/// - Retry automatico per operazioni fallite
/// - Transazioni atomiche per viaggio + items
/// - Logging delle operazioni
class DriftTripRepository implements TripRepository {
  final TripsDao _dao;
  final DatabaseService _dbService;

  DriftTripRepository(this._dao, this._dbService);

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> addTrip(model.TripModel trip) async {
    // Usa transazione atomica per garantire che viaggio e items
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
      },
      operationName: 'addTrip(${trip.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiungere il viaggio: ${result.error}');
    }
    
    debugPrint('[TripRepo] Viaggio aggiunto: ${trip.name} con ${trip.items.length} items');
  }

  @override
  Future<model.TripModel> getTripById(String id) async {
    final result = await _dbService.executeWithRetry(
      () async {
        final trip = await _dao.getTripById(id);
        if (trip == null) return null;
        
        final tripItems = await _dao.getTripItemsByTripId(id);
        return _toModel(trip, tripItems);
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
        final trips = await _dao.getAllTrips();
        final List<model.TripModel> models = [];
        
        for (final trip in trips) {
          try {
            final tripItems = await _dao.getTripItemsByTripId(trip.id);
            models.add(_toModel(trip, tripItems));
          } catch (e) {
            // Se un viaggio ha problemi, logga ma continua con gli altri
            debugPrint('[TripRepo] Errore caricando items per viaggio ${trip.id}: $e');
            models.add(_toModel(trip, []));
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
      },
      operationName: 'updateTrip(${trip.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare il viaggio: ${result.error}');
    }
    
    debugPrint('[TripRepo] Viaggio aggiornato: ${trip.name} con ${trip.items.length} items');
  }

  /// Stream reattivo di tutti i viaggi
  Stream<List<model.TripModel>> watchAllTrips() {
    return _dao.watchAllTrips().asyncMap((trips) async {
      final List<model.TripModel> models = [];
      for (final trip in trips) {
        try {
          final tripItems = await _dao.getTripItemsByTripId(trip.id);
          models.add(_toModel(trip, tripItems));
        } catch (e) {
          debugPrint('[TripRepo] Errore nello stream per viaggio ${trip.id}: $e');
          models.add(_toModel(trip, []));
        }
      }
      return models;
    });
  }

  // === Conversioni ===

  model.TripModel _toModel(Trip trip, List<TripItemEntry> tripItems) {
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
      isSaved: trip.isSaved,
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
    );
  }

  model.TripItem _tripItemToModel(TripItemEntry entry) {
    return model.TripItem(
      id: entry.id,
      name: entry.name,
      category: entry.category,
      quantity: entry.quantity,
      originHouseId: entry.originHouseId,
      isChecked: entry.isChecked,
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
      category: Value(item.category),
      quantity: Value(item.quantity),
      originHouseId: Value(item.originHouseId),
      isChecked: Value(item.isChecked),
    );
  }
}
