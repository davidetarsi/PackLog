import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/item_model.dart';
import '../repositories/local_item_repository.dart';

part 'item_repository.g.dart';

@Riverpod(keepAlive: true)
Future<ItemRepository> itemRepository(Ref ref) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final repository = LocalItemRepository(sharedPreferences);
  await repository.init();
  return repository;
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

