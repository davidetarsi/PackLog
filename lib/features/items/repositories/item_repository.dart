import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/item_model.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/services/persistence_services.dart';
import 'drift_item_repository.dart';

part 'item_repository.g.dart';

@Riverpod(keepAlive: true)
ItemRepository itemRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return DriftItemRepository(
    database.itemsDao,
    dbService,
    () => ref.read(currentUserIdProvider),
  );
}

/// Cosa scrivere con [ItemRepository.updateAiMetadata]: i nuovi metadati AI e,
/// se serve, la nuova categoria.
typedef AiMetadataChange = ({String aiMetadata, ItemCategory? category});

abstract class ItemRepository {
  Future<bool> init();
  Future<void> addItem(ItemModel model);
  Future<ItemModel> getItemById(String id);
  Future<List<ItemModel>> getAllItems();

  /// Colori di base già usati dai capi dell'utente (dai metadati), senza
  /// vuoti e 'N/A', deduplicati e ordinati per frequenza poi alfabetico.
  Future<List<String>> getUsedColors();
  Future<List<ItemModel>> getItemsByHouseId(String houseId);
  Future<bool> deleteItem(String id);
  Future<void> updateItem(ItemModel model);

  /// Aggiorna solo `ai_metadata` (e la categoria, se [compute] la dà) di un
  /// oggetto, dentro una transazione: la riga si rilegge lì e [compute] decide
  /// su quella. Le altre colonne non si toccano, quindi un salvataggio della
  /// scheda concorrente non viene annullato. Segna la riga da sincronizzare
  /// come [updateItem].
  ///
  /// [compute] risponde `null` quando non c'è niente da scrivere. Restituisce
  /// l'oggetto scritto, o `null` se non c'è più o non c'era niente da scrivere.
  /// [compute] può essere chiamata più volte (nuovi tentativi): deve essere
  /// pura.
  Future<ItemModel?> updateAiMetadata(
    String id,
    AiMetadataChange? Function(ItemModel current) compute, {
    DateTime? updatedAt,
  });

  /// Inserisce multipli oggetti in una singola transazione atomica
  Future<void> insertMultipleItems(List<ItemModel> models);

  /// Salva atomicamente i nuovi oggetti della scansione AI nella casa indicata.
  Future<void> saveAiItemsToHouse({
    required String houseId,
    required List<ItemModel> newItems,
  });

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
    String toHouseId, {
    String? spaceId,
  });
}
