import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../model/luggage_model.dart';
import 'luggage_repository.dart';
import '../../../core/database/database.dart';
import '../../../core/database/daos/luggages_dao.dart';
import '../../../core/database/services/database_service.dart';
import '../../../core/database/converters/luggage_size_converter.dart';

/// Implementazione del repository Luggage usando Drift (SQLite).
/// 
/// Fornisce operazioni robuste con:
/// - Retry automatico per operazioni fallite
/// - Transazioni atomiche per junction table operations
/// - Logging delle operazioni
class DriftLuggageRepository implements LuggageRepository {
  final LuggagesDao _dao;
  final DatabaseService _dbService;

  DriftLuggageRepository(this._dao, this._dbService);

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> addLuggage(LuggageModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.insertLuggage(_toCompanion(model)),
      operationName: 'addLuggage(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiungere il bagaglio: ${result.error}');
    }
    
    debugPrint('[LuggageRepo] Bagaglio aggiunto: ${model.name}');
  }

  @override
  Future<LuggageModel> getLuggageById(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getLuggageById(id),
      operationName: 'getLuggageById($id)',
    );
    
    if (!result.success || result.data == null) {
      throw StateError('Bagaglio con id $id non trovato');
    }
    
    return _toModel(result.data!);
  }

  @override
  Future<List<LuggageModel>> getAllLuggages() async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getAllLuggages(),
      operationName: 'getAllLuggages',
    );
    
    if (!result.success) {
      debugPrint('[LuggageRepo] Errore caricando bagagli: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<List<LuggageModel>> getLuggagesByHouseId(String houseId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getLuggagesByHouse(houseId),
      operationName: 'getLuggagesByHouseId($houseId)',
    );
    
    if (!result.success) {
      debugPrint('[LuggageRepo] Errore caricando bagagli per casa: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<bool> deleteLuggage(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.deleteLuggage(id),
      operationName: 'deleteLuggage($id)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      debugPrint('[LuggageRepo] Errore eliminando bagaglio: ${result.error}');
      return false;
    }
    
    debugPrint('[LuggageRepo] Bagaglio eliminato: $id');
    return result.data! > 0;
  }

  @override
  Future<void> updateLuggage(LuggageModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.updateLuggage(_toCompanion(model)),
      operationName: 'updateLuggage(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare il bagaglio: ${result.error}');
    }
    
    debugPrint('[LuggageRepo] Bagaglio aggiornato: ${model.name}');
  }

  @override
  Future<int> countLuggagesByHouse(String houseId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.countLuggagesByHouse(houseId),
      operationName: 'countLuggagesByHouse($houseId)',
    );
    
    if (!result.success) {
      debugPrint('[LuggageRepo] Errore contando bagagli: ${result.error}');
      return 0;
    }
    
    return result.data!;
  }

  @override
  Future<List<LuggageModel>> getLuggagesByTripId(String tripId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getLuggagesByTrip(tripId),
      operationName: 'getLuggagesByTripId($tripId)',
    );
    
    if (!result.success) {
      debugPrint('[LuggageRepo] Errore caricando bagagli per viaggio: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<void> linkLuggageToTrip(String tripId, String luggageId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.linkLuggageToTrip(tripId, luggageId),
      operationName: 'linkLuggageToTrip(trip: $tripId, luggage: $luggageId)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile associare il bagaglio al viaggio: ${result.error}');
    }
    
    debugPrint('[LuggageRepo] Bagaglio $luggageId associato a viaggio $tripId');
  }

  @override
  Future<void> unlinkLuggageFromTrip(String tripId, String luggageId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.unlinkLuggageFromTrip(tripId, luggageId),
      operationName: 'unlinkLuggageFromTrip(trip: $tripId, luggage: $luggageId)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile rimuovere il bagaglio dal viaggio: ${result.error}');
    }
    
    debugPrint('[LuggageRepo] Bagaglio $luggageId rimosso da viaggio $tripId');
  }

  @override
  Future<void> replaceTripLuggages(String tripId, List<String> luggageIds) async {
    final result = await _dbService.executeAtomicWithRetry(
      () => _dao.replaceTripLuggages(tripId, luggageIds),
      operationName: 'replaceTripLuggages(trip: $tripId, count: ${luggageIds.length})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare i bagagli del viaggio: ${result.error}');
    }
    
    debugPrint('[LuggageRepo] Bagagli viaggio $tripId aggiornati: ${luggageIds.length} bagagli');
  }

  /// Stream reattivo di tutti i bagagli di una casa
  Stream<List<LuggageModel>> watchLuggagesByHouseId(String houseId) {
    return _dao.watchLuggagesByHouse(houseId).map(
      (luggages) => luggages.map(_toModel).toList(),
    );
  }

  // === Conversioni ===

  LuggageModel _toModel(Luggage luggage) {
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

  LuggagesCompanion _toCompanion(LuggageModel model) {
    return LuggagesCompanion(
      id: Value(model.id),
      houseId: Value(model.houseId),
      name: Value(model.name),
      sizeType: Value(const LuggageSizeConverter().toSql(model.sizeType)),
      volumeLiters: Value(model.volumeLiters),
      createdAt: Value(model.createdAt),
      updatedAt: Value(model.updatedAt),
    );
  }
}
