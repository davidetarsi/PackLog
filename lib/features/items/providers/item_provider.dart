import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';
import 'item_selection_provider.dart';

part 'item_provider.g.dart';

@Riverpod(keepAlive: true)
class ItemNotifier extends _$ItemNotifier {
  ItemRepository? repository;

  @override
  Future<List<ItemModel>> build(String houseId) async {
    repository = ref.watch(itemRepositoryProvider);
    ref.watch(syncTriggerProvider);
    final items = await repository!.getItemsByHouseId(houseId);
    return items;
  }

  /// Filtra gli items per spazio specifico
  Future<List<ItemModel>> getItemsBySpace(String houseId, String spaceId) async {
    repository ??= ref.read(itemRepositoryProvider);
    return repository!.getItemsBySpaceId(houseId, spaceId);
  }

  /// Ottiene gli items nel pool generale (senza spazio assegnato)
  Future<List<ItemModel>> getItemsInGeneralPool(String houseId) async {
    repository ??= ref.read(itemRepositoryProvider);
    return repository!.getItemsInGeneralPool(houseId);
  }

  Future<void> addItem(ItemModel model) async {
    repository ??= ref.read(itemRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addItem(model);
      final items = await repository!.getItemsByHouseId(model.houseId);
      state = AsyncData(items);
      ref.read(coreAnalyticsServiceProvider).trackItemAdded(
        itemId: model.id,
        category: model.category.name,
        totalItems: items.length,
      );
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateItem(ItemModel model) async {
    repository ??= ref.read(itemRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateItem(model);
      final items = await repository!.getItemsByHouseId(model.houseId);
      state = AsyncData(items);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteItem(String id, String houseId) async {
    repository ??= ref.read(itemRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteItem(id);
      final items = await repository!.getItemsByHouseId(houseId);
      state = AsyncData(items);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh(String houseId) async {
    repository ??= ref.read(itemRepositoryProvider);
    state = const AsyncLoading();
    try {
      final items = await repository!.getItemsByHouseId(houseId);
      state = AsyncData(items);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Elimina [itemIds] in una singola query SQL atomica.
  ///
  /// Al termine:
  /// 1. La lista viene ricaricata dal DB per aggiornare la UI.
  /// 2. La modalità selezione multipla viene azzerata.
  ///
  /// In caso di errore imposta `state = AsyncError` (stesso contratto degli
  /// altri metodi del notifier) — il chiamante può leggere `state.hasError`
  /// oppure catturare l'eccezione se ha bisogno di feedback UI dedicato.
  Future<void> bulkDelete(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    repository ??= ref.read(itemRepositoryProvider);

    try {
      await repository!.deleteItems(itemIds);

      final updated = await repository!.getItemsByHouseId(houseId);
      state = AsyncData(updated);

      ref.read(itemSelectionNotifierProvider.notifier).clear();
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Sposta [itemIds] dalla casa corrente ([houseId]) a [destinationHouseId]
  /// in una singola query SQL atomica.
  ///
  /// Al termine:
  /// 1. La lista della casa di origine viene ricaricata (gli item spariscono).
  /// 2. La modalità selezione multipla viene azzerata.
  /// 3. Il provider della casa di destinazione viene invalidato affinché
  ///    mostri immediatamente i nuovi item se aperto.
  ///
  /// In caso di errore imposta `state = AsyncError` (stesso contratto degli
  /// altri metodi del notifier) — il chiamante può leggere `state.hasError`
  /// oppure catturare l'eccezione se ha bisogno di feedback UI dedicato.
  Future<void> bulkMove(
    List<String> itemIds,
    String destinationHouseId,
  ) async {
    if (itemIds.isEmpty) return;
    repository ??= ref.read(itemRepositoryProvider);

    try {
      // fromHouseId è sempre la casa corrente di questo notifier.
      await repository!.moveItemsToHouse(itemIds, houseId, destinationHouseId);

      final updated = await repository!.getItemsByHouseId(houseId);
      state = AsyncData(updated);

      ref.invalidate(itemNotifierProvider(destinationHouseId));
      ref.read(itemSelectionNotifierProvider.notifier).clear();
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
