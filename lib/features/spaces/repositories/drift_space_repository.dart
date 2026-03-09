import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../model/space_model.dart';
import 'space_repository.dart';
import '../../../core/database/database.dart';
import '../../../core/database/daos/spaces_dao.dart';
import '../../../core/database/services/database_service.dart';

/// Implementazione del repository Space usando Drift (SQLite).
/// 
/// Fornisce operazioni robuste con:
/// - Retry automatico per operazioni fallite
/// - Transazioni atomiche
/// - Logging delle operazioni
class DriftSpaceRepository implements SpaceRepository {
  final SpacesDao _dao;
  final DatabaseService _dbService;

  DriftSpaceRepository(this._dao, this._dbService);

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> addSpace(SpaceModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.insertSpace(_toCompanion(model)),
      operationName: 'addSpace(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiungere lo spazio: ${result.error}');
    }
    
    debugPrint('[SpaceRepo] Spazio aggiunto: ${model.name}');
  }

  @override
  Future<SpaceModel> getSpaceById(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getSpaceById(id),
      operationName: 'getSpaceById($id)',
    );
    
    if (!result.success || result.data == null) {
      throw StateError('Spazio con id $id non trovato');
    }
    
    return _toModel(result.data!);
  }

  @override
  Future<List<SpaceModel>> getAllSpaces() async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getAllSpaces(),
      operationName: 'getAllSpaces',
    );
    
    if (!result.success) {
      debugPrint('[SpaceRepo] Errore caricando spazi: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<List<SpaceModel>> getSpacesByHouseId(String houseId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getSpacesByHouse(houseId),
      operationName: 'getSpacesByHouseId($houseId)',
    );
    
    if (!result.success) {
      debugPrint('[SpaceRepo] Errore caricando spazi per casa: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<bool> deleteSpace(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.deleteSpace(id),
      operationName: 'deleteSpace($id)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      debugPrint('[SpaceRepo] Errore eliminando spazio: ${result.error}');
      return false;
    }
    
    debugPrint('[SpaceRepo] Spazio eliminato: $id');
    return result.data! > 0;
  }

  @override
  Future<void> updateSpace(SpaceModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.updateSpace(_toCompanion(model)),
      operationName: 'updateSpace(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare lo spazio: ${result.error}');
    }
    
    debugPrint('[SpaceRepo] Spazio aggiornato: ${model.name}');
  }

  @override
  Future<int> countSpacesByHouse(String houseId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.countSpacesByHouse(houseId),
      operationName: 'countSpacesByHouse($houseId)',
    );
    
    if (!result.success) {
      debugPrint('[SpaceRepo] Errore contando spazi: ${result.error}');
      return 0;
    }
    
    return result.data!;
  }

  /// Stream reattivo di tutti gli spazi di una casa
  Stream<List<SpaceModel>> watchSpacesByHouseId(String houseId) {
    return _dao.watchSpacesByHouse(houseId).map(
      (spaces) => spaces.map(_toModel).toList(),
    );
  }

  // === Conversioni ===

  SpaceModel _toModel(Space space) {
    return SpaceModel(
      id: space.id,
      houseId: space.houseId,
      name: space.name,
      iconName: space.iconName,
      createdAt: space.createdAt,
      updatedAt: space.updatedAt,
    );
  }

  SpacesCompanion _toCompanion(SpaceModel model) {
    return SpacesCompanion(
      id: Value(model.id),
      houseId: Value(model.houseId),
      name: Value(model.name),
      iconName: Value(model.iconName),
      createdAt: Value(model.createdAt),
      updatedAt: Value(model.updatedAt),
    );
  }
}
