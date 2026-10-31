import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/item_metadata_merge.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';
import 'item_enrichment_provider.dart';
import 'item_metadata_service_provider.dart';
import 'item_selection_provider.dart';
import 'user_colors_provider.dart';

part 'item_provider.g.dart';

@Riverpod(keepAlive: true)
class ItemNotifier extends _$ItemNotifier with SyncedCrudNotifier<ItemModel> {
  ItemRepository get _repo => ref.read(itemRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  /// Numero dell'ultima richiesta di scheda per ogni oggetto. Solo l'ultima
  /// può scrivere e chiudere l'attesa: vedi [_schedaDalNome].
  final Map<String, int> _schedaRichieste = {};

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

  /// Aggiunge un oggetto. Se è stato scritto a mano (senza scheda, o con solo le
  /// scelte dell'utente: vedi [needsAiMetadata]) la scheda arriva subito dopo da
  /// `item-metadata`, senza far aspettare chi lo aggiunge: vedi
  /// [_schedaDalNome]. [categoryChosen] dice se la categoria l'ha scelta
  /// l'utente: in quel caso il server non la cambia.
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
    ref.invalidate(userColorsProvider);
    if (needsAiMetadata(model.aiMetadata) && model.name.trim().isNotEmpty) {
      unawaited(_schedaDalNome(model, categoryChosen: categoryChosen));
    }
  }

  /// La scheda di un oggetto scritto a mano, chiesta a `item-metadata` dal
  /// nome. Mentre aspetta l'oggetto è in [itemEnrichmentProvider]. La risposta
  /// si scrive solo se è la richiesta più recente per l'oggetto, nel frattempo
  /// l'oggetto esiste ancora ed ha lo stesso nome, e l'AI ha ancora qualcosa da
  /// completare; i campi scelti dall'utente restano suoi (vedi
  /// [mergeAiMetadata]). La categoria cambia solo se l'utente non l'aveva
  /// scelta e non l'ha toccata dopo. Senza rete o a limite raggiunto l'oggetto
  /// resta com'è.
  Future<void> _schedaDalNome(
    ItemModel model, {
    required bool categoryChosen,
  }) async {
    final id = model.id;
    final richiesta = (_schedaRichieste[id] ?? 0) + 1;
    _schedaRichieste[id] = richiesta;
    bool laPiuRecente() => _schedaRichieste[id] == richiesta;

    final attesa = ref.read(itemEnrichmentProvider.notifier);
    attesa.start(id);
    try {
      final scheda = await ref
          .read(itemMetadataServiceProvider)
          .fromName(model.name);
      if (scheda == null || !laPiuRecente()) return;
      // Le guardie girano sulla riga riletta dentro la transazione: un
      // salvataggio della scheda concorrente non viene annullato.
      await mutate(
        operation: () async {
          await _repo.updateAiMetadata(id, (current) {
            if (!laPiuRecente() ||
                current.name != model.name ||
                !needsAiMetadata(current.aiMetadata)) {
              return null;
            }
            return (
              aiMetadata: mergeAiMetadata(
                current: current.aiMetadata,
                ai: scheda.metadata,
              ),
              category:
                  !categoryChosen &&
                      current.category == model.category &&
                      scheda.category != null
                  ? scheda.category
                  : null,
            );
          });
        },
        reload: () => _repo.getItemsByHouseId(houseId),
        // Scrittura in background: se fallisce la lista resta com'è (il catch
        // qui sotto la registra), non diventa AsyncError.
        rethrowOnly: true,
        onSuccess: (_) => ref.invalidate(userColorsProvider),
      );
    } catch (e) {
      debugPrint('[ItemNotifier] scheda dal nome non salvata: $e');
    } finally {
      if (laPiuRecente()) attesa.finish(id);
    }
  }

  /// Salva un oggetto. Se è stato rinominato e i suoi metadati aspettano
  /// ancora l'AI, la scheda si chiede di nuovo col nome nuovo; la risposta del
  /// nome vecchio, se arriva, si scarta. La categoria non cambia: l'utente l'ha
  /// già vista.
  Future<void> updateItem(ItemModel model) async {
    final previous = state.value?.where((i) => i.id == model.id).firstOrNull;
    await mutate(
      operation: () => _repo.updateItem(model),
      reload: () => _repo.getItemsByHouseId(houseId),
      rethrowOnly: true,
      onSuccess: (_) {
        _analytics.trackItemUpdated(category: model.category.name);
        ref.invalidate(userColorsProvider);
      },
    );
    if (previous != null &&
        previous.name != model.name &&
        model.name.trim().isNotEmpty &&
        needsAiMetadata(model.aiMetadata)) {
      unawaited(_schedaDalNome(model, categoryChosen: true));
    }
  }

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
