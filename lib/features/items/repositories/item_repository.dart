import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/item_model.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/services/persistence_services.dart';
import 'drift_item_repository.dart';

part 'item_repository.g.dart';

@Riverpod(keepAlive: true)
ItemRepository itemRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return DriftItemRepository(database.itemsDao, dbService);
}

abstract class ItemRepository {
  Future<bool> init();
  Future<void> addItem(ItemModel model);
  Future<ItemModel> getItemById(String id);
  Future<List<ItemModel>> getAllItems();
  Future<List<ItemModel>> getItemsByHouseId(String houseId);
  Future<bool> deleteItem(String id);
  Future<void> updateItem(ItemModel model);
  
  /// Inserisce multipli oggetti in una singola transazione atomica
  Future<void> insertMultipleItems(List<ItemModel> models);
  
  /// Ottiene gli oggetti di una casa filtrati per spazio specifico
  Future<List<ItemModel>> getItemsBySpaceId(String houseId, String spaceId);
  
  /// Ottiene gli oggetti nel pool generale di una casa (spaceId == null)
  Future<List<ItemModel>> getItemsInGeneralPool(String houseId);
  
  /// Conta gli oggetti in uno spazio specifico
  Future<int> countItemsBySpace(String spaceId);

  /// Elimina più oggetti in una singola query SQL.
  ///
  /// Idempotente: se [itemIds] è vuota non esegue operazioni.
  Future<void> deleteItems(List<String> itemIds);

  /// Returns all non-deleted items whose category is in [categories].
  ///
  /// Used by [PackingInventoryService] to fetch the two inventory buckets
  /// (wardrobe = [ItemCategory.vestiti], essentials = everything else)
  /// in a single targeted query.
  Future<List<ItemModel>> getAllItemsByCategories(List<ItemCategory> categories);

  /// Sposta [itemIds] da [fromHouseId] a [toHouseId] in una singola query SQL.
  ///
  /// La query filtra per `house_id = fromHouseId`: solo gli item che si trovano
  /// *ancora* nella casa di origine vengono spostati. Item già trasferiti o
  /// manualmente ricollocati altrove non vengono modificati.
  ///
  /// Usato da [TripNotifier._transferItemsForCompletedTrips] per trasferire
  /// gli item al completamento di un viaggio inter-casa, senza il pattern N+1.
  Future<void> moveItemsToHouse(
    List<String> itemIds,
    String fromHouseId,
    String toHouseId,
  );
}
