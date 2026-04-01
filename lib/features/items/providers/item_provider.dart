import 'package:riverpod_annotation/riverpod_annotation.dart';
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
  /// Lancia un'eccezione se l'operazione fallisce (il chiamante gestisce l'UI).
  Future<void> bulkDelete(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    repository ??= ref.read(itemRepositoryProvider);

    await repository!.deleteItems(itemIds);

    // Aggiorna la lista locale senza passare per AsyncLoading
    // per evitare un flash di schermata di caricamento.
    final updated = await repository!.getItemsByHouseId(houseId);
    state = AsyncData(updated);

    // Esce dalla modalità selezione: l'utente ha completato l'operazione.
    ref.read(itemSelectionNotifierProvider.notifier).clear();
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
  /// Lancia un'eccezione se l'operazione fallisce (il chiamante gestisce l'UI).
  Future<void> bulkMove(
    List<String> itemIds,
    String destinationHouseId,
  ) async {
    if (itemIds.isEmpty) return;
    repository ??= ref.read(itemRepositoryProvider);

    // fromHouseId è sempre la casa corrente di questo notifier.
    await repository!.moveItemsToHouse(itemIds, houseId, destinationHouseId);

    // Aggiorna la lista sorgente senza flash di caricamento.
    final updated = await repository!.getItemsByHouseId(houseId);
    state = AsyncData(updated);

    // Invalida la destinazione: se l'utente naviga lì troverà la lista fresca.
    ref.invalidate(itemNotifierProvider(destinationHouseId));

    // Esce dalla modalità selezione.
    ref.read(itemSelectionNotifierProvider.notifier).clear();
  }
}
