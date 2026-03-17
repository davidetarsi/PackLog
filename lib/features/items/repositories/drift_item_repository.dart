import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../model/item_model.dart';
import 'item_repository.dart';
import '../../../core/database/converters/item_category_converter.dart';
import '../../../core/database/database.dart';
import '../../../core/database/daos/items_dao.dart';
import '../../../core/database/services/database_service.dart';

/// Implementazione del repository Item usando Drift (SQLite).
/// 
/// Fornisce operazioni robuste con:
/// - Retry automatico per operazioni fallite
/// - Transazioni atomiche
/// - Logging delle operazioni
class DriftItemRepository implements ItemRepository {
  final ItemsDao _dao;
  final DatabaseService _dbService;

  DriftItemRepository(this._dao, this._dbService);

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> addItem(ItemModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.insertItem(_toCompanion(model)),
      operationName: 'addItem(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiungere l\'oggetto: ${result.error}');
    }
    
    debugPrint('[ItemRepo] Oggetto aggiunto: ${model.name}');
  }

  @override
  Future<ItemModel> getItemById(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getItemById(id),
      operationName: 'getItemById($id)',
    );
    
    if (!result.success || result.data == null) {
      throw StateError('Oggetto con id $id non trovato');
    }
    
    return _toModel(result.data!);
  }

  @override
  Future<List<ItemModel>> getAllItems() async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getAllItems(),
      operationName: 'getAllItems',
    );
    
    if (!result.success) {
      debugPrint('[ItemRepo] Errore caricando oggetti: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<List<ItemModel>> getItemsByHouseId(String houseId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getItemsByHouseId(houseId),
      operationName: 'getItemsByHouseId($houseId)',
    );
    
    if (!result.success) {
      debugPrint('[ItemRepo] Errore caricando oggetti per casa: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<bool> deleteItem(String id) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.deleteItem(id),
      operationName: 'deleteItem($id)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      debugPrint('[ItemRepo] Errore eliminando oggetto: ${result.error}');
      return false;
    }
    
    debugPrint('[ItemRepo] Oggetto eliminato: $id');
    return result.data! > 0;
  }

  @override
  Future<void> updateItem(ItemModel model) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.updateItem(_toCompanion(model)),
      operationName: 'updateItem(${model.name})',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile aggiornare l\'oggetto: ${result.error}');
    }
    
    debugPrint('[ItemRepo] Oggetto aggiornato: ${model.name}');
  }

  @override
  Future<void> insertMultipleItems(List<ItemModel> models) async {
    if (models.isEmpty) {
      debugPrint('[ItemRepo] insertMultipleItems: lista vuota, skip');
      return;
    }

    final companions = models.map(_toCompanion).toList();
    
    final result = await _dbService.executeWithRetry(
      () => _dao.insertMultipleItems(companions),
      operationName: 'insertMultipleItems(${models.length} items)',
      config: RetryConfig.criticalConfig,
    );
    
    if (!result.success) {
      throw Exception('Impossibile inserire gli oggetti: ${result.error}');
    }
    
    debugPrint('[ItemRepo] ${models.length} oggetti inseriti con successo');
  }

  /// Stream reattivo di tutti gli oggetti
  Stream<List<ItemModel>> watchAllItems() {
    return _dao.watchAllItems().map(
      (items) => items.map(_toModel).toList(),
    );
  }

  /// Stream reattivo degli oggetti di una casa
  Stream<List<ItemModel>> watchItemsByHouseId(String houseId) {
    return _dao.watchItemsByHouseId(houseId).map(
      (items) => items.map(_toModel).toList(),
    );
  }

  // === Conversioni ===

  @override
  Future<List<ItemModel>> getItemsBySpaceId(String houseId, String spaceId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getItemsBySpaceId(houseId, spaceId),
      operationName: 'getItemsBySpaceId(house: $houseId, space: $spaceId)',
    );
    
    if (!result.success) {
      debugPrint('[ItemRepo] Errore caricando items per spazio: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<List<ItemModel>> getItemsInGeneralPool(String houseId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.getItemsInGeneralPool(houseId),
      operationName: 'getItemsInGeneralPool($houseId)',
    );
    
    if (!result.success) {
      debugPrint('[ItemRepo] Errore caricando items pool generale: ${result.error}');
      return [];
    }
    
    return result.data!.map(_toModel).toList();
  }

  @override
  Future<int> countItemsBySpace(String spaceId) async {
    final result = await _dbService.executeWithRetry(
      () => _dao.countItemsBySpace(spaceId),
      operationName: 'countItemsBySpace($spaceId)',
    );
    
    if (!result.success) {
      debugPrint('[ItemRepo] Errore contando items per spazio: ${result.error}');
      return 0;
    }
    
    return result.data!;
  }

  /// Stream reattivo degli oggetti filtrati per spazio
  Stream<List<ItemModel>> watchItemsBySpaceId(String houseId, String spaceId) {
    return _dao.watchItemsBySpaceId(houseId, spaceId).map(
      (items) => items.map(_toModel).toList(),
    );
  }

  /// Stream reattivo degli oggetti nel pool generale
  Stream<List<ItemModel>> watchItemsInGeneralPool(String houseId) {
    return _dao.watchItemsInGeneralPool(houseId).map(
      (items) => items.map(_toModel).toList(),
    );
  }

  // === Conversioni ===

  ItemModel _toModel(Item item) {
    return ItemModel(
      id: item.id,
      houseId: item.houseId,
      name: item.name,
      category: ItemCategoryConverter.fromDatabase(item.category),
      description: item.description,
      quantity: item.quantity,
      spaceId: item.spaceId,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  ItemsCompanion _toCompanion(ItemModel model) {
    return ItemsCompanion(
      id: Value(model.id),
      houseId: Value(model.houseId),
      name: Value(model.name),
      category: Value(ItemCategoryConverter.toDatabase(model.category)),
      description: Value(model.description),
      quantity: Value(model.quantity),
      spaceId: Value(model.spaceId),
      createdAt: Value(model.createdAt),
      updatedAt: Value(model.updatedAt),
    );
  }
}
