import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';

part 'item_provider.g.dart';

@Riverpod(keepAlive: true)
class ItemNotifier extends _$ItemNotifier {
  ItemRepository? repository;

  @override
  Future<List<ItemModel>> build(String houseId) async {
    repository = await ref.watch(itemRepositoryProvider.future);
    final items = await repository!.getItemsByHouseId(houseId);
    return items;
  }

  Future<void> addItem(ItemModel model) async {
    repository ??= await ref.read(itemRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      await repository!.addItem(model);
      final items = await repository!.getItemsByHouseId(model.houseId);
      state = AsyncData(items);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateItem(ItemModel model) async {
    repository ??= await ref.read(itemRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      await repository!.updateItem(model);
      final items = await repository!.getItemsByHouseId(model.houseId);
      state = AsyncData(items);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteItem(String id, String houseId) async {
    repository ??= await ref.read(itemRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      await repository!.deleteItem(id);
      final items = await repository!.getItemsByHouseId(houseId);
      state = AsyncData(items);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh(String houseId) async {
    repository ??= await ref.read(itemRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      final items = await repository!.getItemsByHouseId(houseId);
      state = AsyncData(items);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

