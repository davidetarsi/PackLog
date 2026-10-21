import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';
import 'item_metadata_service_provider.dart';
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

  /// Aggiunge un oggetto. Se è stato scritto a mano (niente [ItemModel.aiMetadata])
  /// la scheda arriva subito dopo da `item-metadata`, senza far aspettare chi
  /// lo aggiunge: vedi [_schedaDalNome]. [categoryChosen] dice se la categoria
  /// l'ha scelta l'utente: in quel caso il server non la cambia.
  Future<void> addItem(ItemModel model, {bool categoryChosen = false}) async {
    await mutate(
      operation: () => _repo.addItem(model),
      reload: () => _repo.getItemsByHouseId(houseId),
      rethrowOnly: true,
      onSuccess: (items) => _analytics.trackItemAdded(
        itemId: model.id,
        houseId: model.houseId,
        category: model.category.name,
        totalItems: items.length,
      ),
    );
    if (model.aiMetadata == null && model.name.trim().isNotEmpty) {
      unawaited(_schedaDalNome(model, categoryChosen: categoryChosen));
    }
  }

  /// La scheda di un oggetto aggiunto a mano, chiesta a `item-metadata` dal
  /// nome. Si scrive solo se nel frattempo l'oggetto esiste ancora, ha lo
  /// stesso nome e nessuno gli ha già dato una scheda; la categoria cambia
  /// solo se l'utente non l'aveva scelta e non l'ha toccata dopo. Senza rete o
  /// a limite raggiunto l'oggetto resta com'è.
  Future<void> _schedaDalNome(
    ItemModel model, {
    required bool categoryChosen,
  }) async {
    try {
      final scheda = await ref
          .read(itemMetadataServiceProvider)
          .fromName(model.name);
      if (scheda == null) return;
      final current = await _repo.getItemById(model.id);
      if (current.name != model.name || current.aiMetadata != null) return;
      final category =
          !categoryChosen &&
              current.category == model.category &&
              scheda.category != null
          ? scheda.category!
          : current.category;
      final updated = current.copyWith(
        aiMetadata: jsonEncode(scheda.metadata),
        category: category,
        updatedAt: DateTime.now(),
      );
      await mutate(
        operation: () => _repo.updateItem(updated),
        reload: () => _repo.getItemsByHouseId(houseId),
        rethrowOnError: false,
      );
    } catch (e) {
      debugPrint('[ItemNotifier] scheda dal nome non salvata: $e');
    }
  }

  Future<void> updateItem(ItemModel model) => mutate(
    operation: () => _repo.updateItem(model),
    reload: () => _repo.getItemsByHouseId(houseId),
    rethrowOnly: true,
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
      rethrowOnly: true,
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
      rethrowOnly: true,
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
      rethrowOnly: true,
      onSuccess: (_) {
        _analytics.trackItemBulkMoved(count: itemIds.length);
        ref.invalidate(itemNotifierProvider(destinationHouseId));
        ref.read(itemSelectionNotifierProvider.notifier).clear();
      },
    );
  }
}
