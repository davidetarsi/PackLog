import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';
import '../../../shared/constants/app_constants.dart';

class LocalItemRepository implements ItemRepository {
  final SharedPreferences _sharedPreferences;
  
  LocalItemRepository(this._sharedPreferences);
  
  @override
  Future<bool> init() async {
    return true;
  }
  
  @override
  Future<void> addItem(ItemModel model) async {
    final items = await getAllItems();
    final updatedItems = [...items, model];
    await _saveItems(updatedItems);
  }

  @override
  Future<ItemModel> getItemById(String id) async {
    final items = await getAllItems();
    return items.firstWhere((item) => item.id == id);
  }

  @override
  Future<List<ItemModel>> getAllItems() async {
    final itemsJson = _sharedPreferences.getStringList(AppConstants.itemsKey) ?? [];
    return itemsJson
        .map((json) => ItemModel.fromJson(jsonDecode(json)))
        .toList();
  }

  @override
  Future<List<ItemModel>> getItemsByHouseId(String houseId) async {
    final items = await getAllItems();
    return items.where((item) => item.houseId == houseId).toList();
  }

  @override
  Future<bool> deleteItem(String id) async {
    final items = await getAllItems();
    items.removeWhere((item) => item.id == id);
    await _saveItems(items);
    return true;
  }

  @override
  Future<void> updateItem(ItemModel model) async {
    final items = await getAllItems();
    final index = items.indexWhere((i) => i.id == model.id);
    if (index != -1) {
      final updatedItem = model.copyWith(updatedAt: DateTime.now());
      items[index] = updatedItem;
      await _saveItems(items);
    }
  }

  Future<void> _saveItems(List<ItemModel> items) async {
    final itemsJson = items.map((i) => jsonEncode(i.toJson())).toList();
    await _sharedPreferences.setStringList(AppConstants.itemsKey, itemsJson);
  }
}

