import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../model/house_model.dart';
import 'house_repository.dart';
import '../../../core/database/database.dart';
import '../../../core/database/daos/houses_dao.dart';
import '../../../core/database/services/database_service.dart';

/// Implementazione del repository House usando Drift (SQLite).
/// 
/// Fornisce operazioni robuste con:
/// - Retry automatico per operazioni fallite
/// - Transazioni atomiche
/// - Logging delle operazioni
class DriftHouseRepository implements HouseRepository {
  final HousesDao _dao;
  final DatabaseService _dbService;

  DriftHouseRepository(this._dao, this._dbService);

  @override
  Future<bool> init() async {
    // Non serve inizializzazione, Drift gestisce tutto
    return true;
  }

  @override
  Future<void> addHouse(HouseModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.insertHouse(_toCompanion(model)),
      operationName: 'addHouse(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiungere la casa: ${result.error}');
    }
    
    debugPrint('[HouseRepo] Casa aggiunta: ${model.name}');
  }

  @override
  Future<HouseModel> getHouseById(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getHouseById(id),
      operationName: 'getHouseById($id)',
    );
    
    if (!result.success || result.data == null) {
      throw StateError('Casa con id $id non trovata');
    }
    
    return _toModel(result.data!);
  }

  @override
  Future<List<HouseModel>> getAllHouses() async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getAllHouses(),
      operationName: 'getAllHouses',
    );
    
    if (!result.success) {
      debugPrint('[HouseRepo] Errore caricando case: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<bool> deleteHouse(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.deleteHouse(id),
      operationName: 'deleteHouse($id)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      debugPrint('[HouseRepo] Errore eliminando casa: ${result.error}');
      return false;
    }
    
    debugPrint('[HouseRepo] Casa eliminata: $id');
    return result.data! > 0;
  }

  @override
  Future<void> updateHouse(HouseModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.updateHouse(_toCompanion(model)),
      operationName: 'updateHouse(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare la casa: ${result.error}');
    }
    
    debugPrint('[HouseRepo] Casa aggiornata: ${model.name}');
  }

  /// Stream reattivo di tutte le case
  Stream<List<HouseModel>> watchAllHouses() {
    return _dao.watchAllHouses().map(
      (houses) => houses.map(_toModel).toList(),
    );
  }

  // === Conversioni ===

  HouseModel _toModel(House house) {
    return HouseModel(
      id: house.id,
      name: house.name,
      description: house.description,
      createdAt: house.createdAt,
      updatedAt: house.updatedAt,
    );
  }

  HousesCompanion _toCompanion(HouseModel model) {
    return HousesCompanion(
      id: Value(model.id),
      name: Value(model.name),
      description: Value(model.description),
      createdAt: Value(model.createdAt),
      updatedAt: Value(model.updatedAt),
    );
  }
}
