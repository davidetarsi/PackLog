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
}
