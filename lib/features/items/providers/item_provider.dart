import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';
import 'item_selection_provider.dart';

part 'item_provider.g.dart';

@Riverpod(keepAlive: true)
class ItemNotifier extends _$ItemNotifier with SyncedCrudNotifier<ItemModel> {
  ItemRepository get _repo => ref.read(itemRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  @override
  Future<List<ItemModel>> build(String houseId) async {
    ref.watch(syncTriggerProvider);
    return _repo.getItemsByHouseId(houseId);
  }

  @override
  void onMutationSuccess(List<ItemModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
  }

  /// Filtra gli items per spazio specifico
  Future<List<ItemModel>> getItemsBySpace(String houseId, String spaceId) =>
      _repo.getItemsBySpaceId(houseId, spaceId);

  /// Ottiene gli items nel pool generale (senza spazio assegnato)
  Future<List<ItemModel>> getItemsInGeneralPool(String houseId) =>
      _repo.getItemsInGeneralPool(houseId);

  Future<void> addItem(ItemModel model) => mutate(
    operation: () => _repo.addItem(model),
    reload: () => _repo.getItemsByHouseId(houseId),
    onSuccess: (items) => _analytics.trackItemAdded(
      itemId: model.id,
      category: model.category.name,
      totalItems: items.length,
    ),
  );

  Future<void> updateItem(ItemModel model) => mutate(
    operation: () => _repo.updateItem(model),
    reload: () => _repo.getItemsByHouseId(houseId),
    onSuccess: (_) =>
        _analytics.trackItemUpdated(category: model.category.name),
  );

  Future<void> deleteItem(String id, String houseId) async {
    // Leggi la category prima di mutate (state è ancora valido qui)
    final category = state.value
        ?.where((i) => i.id == id)
        .firstOrNull
        ?.category
        .name;
    await mutate(
      operation: () => _repo.deleteItem(id),
      reload: () => _repo.getItemsByHouseId(houseId),
      onSuccess: (_) {
        if (category != null) {
          _analytics.trackItemDeleted(category: category);
        }
      },
    );
  }

  Future<void> refresh(String houseId) => mutate(
    operation: () async {},
    reload: () => _repo.getItemsByHouseId(houseId),
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );

  /// Elimina [itemIds] in una singola query SQL atomica.
  Future<void> bulkDelete(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    await mutate(
      operation: () => _repo.deleteItems(itemIds),
      reload: () => _repo.getItemsByHouseId(houseId),
      onSuccess: (_) {
        _analytics.trackItemBulkDeleted(count: itemIds.length);
        ref.read(itemSelectionNotifierProvider.notifier).clear();
      },
    );
  }

  /// Sposta [itemIds] a [destinationHouseId] in una singola query SQL atomica.
  Future<void> bulkMove(
    List<String> itemIds,
    String destinationHouseId, {
    String? spaceId,
  }) async {
    if (itemIds.isEmpty) return;
    await mutate(
      operation: () => _repo.moveItemsToHouse(
        itemIds,
        houseId,
        destinationHouseId,
        spaceId: spaceId,
      ),
      reload: () => _repo.getItemsByHouseId(houseId),
      onSuccess: (_) {
        _analytics.trackItemBulkMoved(count: itemIds.length);
        ref.invalidate(itemNotifierProvider(destinationHouseId));
        ref.read(itemSelectionNotifierProvider.notifier).clear();
      },
    );
  }
}
