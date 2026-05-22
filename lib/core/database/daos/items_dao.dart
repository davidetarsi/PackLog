import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/items_table.dart';
import '../tables/mixins/syncable_table.dart';

part 'items_dao.g.dart';

/// DAO per le operazioni CRUD sugli oggetti.
@DriftAccessor(tables: [Items])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  /// Ottiene tutti gli oggetti non eliminati
  Future<List<Item>> getAllItems() =>
      (select(items)..where((i) => i.isDeleted.equals(false))).get();

  /// Ottiene tutti gli oggetti non eliminati come stream
  Stream<List<Item>> watchAllItems() =>
      (select(items)..where((i) => i.isDeleted.equals(false))).watch();

  /// Ottiene gli oggetti non eliminati di una casa specifica
  Future<List<Item>> getItemsByHouseId(String houseId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.isDeleted.equals(false)))
        .get();
  }

  /// Ottiene gli oggetti non eliminati di una casa come stream
  Stream<List<Item>> watchItemsByHouseId(String houseId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.isDeleted.equals(false)))
        .watch();
  }

  /// Ottiene un oggetto per ID (solo se non eliminato)
  Future<Item?> getItemById(String id) {
    return (select(items)
          ..where((i) => i.id.equals(id) & i.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Ottiene un oggetto per ID indipendentemente dal flag isDeleted.
  /// Usato dal sync per rilevare record locali prima di insert/update da remoto.
  Future<Item?> findItemById(String id) {
    return (select(items)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce un nuovo oggetto
  Future<int> insertItem(ItemsCompanion item) {
    return into(items).insert(item);
  }

  /// Aggiorna un oggetto esistente
  Future<bool> updateItem(ItemsCompanion item) {
    return update(items).replace(item);
  }

  /// Soft-delete di un singolo oggetto
  Future<int> deleteItem(String id) {
    return (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-delete di tutti gli oggetti di una casa.
  ///
  /// Usato internamente dal cascade di [HousesDao.deleteHouse].
  /// Agisce solo sui record non già eliminati.
  Future<int> deleteItemsByHouseId(String houseId) {
    return (update(items)
          ..where((i) => i.houseId.equals(houseId) & i.isDeleted.equals(false)))
        .write(
          ItemsCompanion(
            isDeleted: const Value(true),
            syncStatus: const Value(SyncStatus.pendingUpdate),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Inserisce multiple oggetti (per migrazione)
  Future<void> insertMultipleItems(List<ItemsCompanion> itemsList) async {
    await batch((batch) {
      batch.insertAll(items, itemsList);
    });
  }

  // === Space Filtering Methods ===

  /// Ottiene gli oggetti non eliminati di una casa filtrati per spazio specifico
  Future<List<Item>> getItemsBySpaceId(String houseId, String spaceId) {
    return (select(items)..where(
          (i) =>
              i.houseId.equals(houseId) &
              i.spaceId.equals(spaceId) &
              i.isDeleted.equals(false),
        ))
        .get();
  }

  /// Ottiene gli oggetti non eliminati nel pool generale di una casa (spaceId == null)
  Future<List<Item>> getItemsInGeneralPool(String houseId) {
    return (select(items)..where(
          (i) =>
              i.houseId.equals(houseId) &
              i.spaceId.isNull() &
              i.isDeleted.equals(false),
        ))
        .get();
  }

  /// Stream degli oggetti non eliminati filtrati per spazio
  Stream<List<Item>> watchItemsBySpaceId(String houseId, String spaceId) {
    return (select(items)..where(
          (i) =>
              i.houseId.equals(houseId) &
              i.spaceId.equals(spaceId) &
              i.isDeleted.equals(false),
        ))
        .watch();
  }

  /// Stream degli oggetti non eliminati nel pool generale
  Stream<List<Item>> watchItemsInGeneralPool(String houseId) {
    return (select(items)..where(
          (i) =>
              i.houseId.equals(houseId) &
              i.spaceId.isNull() &
              i.isDeleted.equals(false),
        ))
        .watch();
  }

  /// Conta gli oggetti non eliminati in uno spazio specifico
  Future<int> countItemsBySpace(String spaceId) async {
    final query = selectOnly(items)
      ..addColumns([items.id.count()])
      ..where(items.spaceId.equals(spaceId) & items.isDeleted.equals(false));

    final result = await query.getSingleOrNull();
    return result?.read(items.id.count()) ?? 0;
  }

  /// Conta gli oggetti non eliminati nel pool generale di una casa
  Future<int> countItemsInGeneralPool(String houseId) async {
    final query = selectOnly(items)
      ..addColumns([items.id.count()])
      ..where(
        items.houseId.equals(houseId) &
            items.spaceId.isNull() &
            items.isDeleted.equals(false),
      );

    final result = await query.getSingleOrNull();
    return result?.read(items.id.count()) ?? 0;
  }

  /// Soft-delete di più oggetti in una singola query SQL:
  /// `UPDATE items SET is_deleted = 1 WHERE id IN (?)`
  ///
  /// Idempotente: se la lista è vuota non esegue alcuna query.
  Future<void> deleteItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    await (update(items)..where((t) => t.id.isIn(itemIds))).write(
      ItemsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // === SYNC OPERATIONS ===

  Future<void> purgeItem(String id) {
    return (delete(items)..where((i) => i.id.equals(id))).go();
  }

  Future<int> markDeletedAsPendingSync() {
    return (update(items)..where(
          (i) =>
              i.isDeleted.equals(true) &
              i.syncStatus.equalsValue(SyncStatus.synced),
        ))
        .write(
          const ItemsCompanion(syncStatus: Value(SyncStatus.pendingUpdate)),
        );
  }

  Future<List<Item>> getPendingSyncItems({int maxRetries = 5}) {
    final now = DateTime.now();
    return (select(items)..where(
          (i) =>
              i.syncStatus.equalsValue(SyncStatus.synced).not() &
              i.syncRetryCount.isSmallerThanValue(maxRetries) &
              (i.nextSyncAttemptAt.isNull() |
                  i.nextSyncAttemptAt.isSmallerOrEqualValue(now)),
        ))
        .get();
  }

  Future<void> markItemAsSynced(String itemId, DateTime serverUpdatedAt) {
    return (update(items)..where((i) => i.id.equals(itemId))).write(
      ItemsCompanion(
        syncStatus: const Value(SyncStatus.synced),
        syncRetryCount: const Value(0),
        lastSyncError: const Value(null),
        lastSyncedAt: Value(serverUpdatedAt),
        nextSyncAttemptAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementSyncRetry(String itemId, String errorMessage) async {
    final item = await (select(
      items,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item == null) return;

    final newRetryCount = item.syncRetryCount + 1;
    final backoffSeconds = 2 << (newRetryCount - 1);
    final nextAttempt = DateTime.now().add(Duration(seconds: backoffSeconds));

    await (update(items)..where((i) => i.id.equals(itemId))).write(
      ItemsCompanion(
        syncRetryCount: Value(newRetryCount),
        lastSyncError: Value(errorMessage),
        nextSyncAttemptAt: Value(nextAttempt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // === BULK OPERATIONS ===

  /// Sposta un set di oggetti da [fromHouseId] a [toHouseId] in una singola
  /// query SQL:
  /// `UPDATE items SET house_id = ? WHERE id IN (?) AND house_id = ?`
  ///
  /// Il filtro `AND house_id = fromHouseId` è **critico per la correttezza**:
  /// garantisce che vengano spostati solo gli item che si trovano *ancora*
  /// nella casa di partenza del viaggio. Se un item è già stato trasferito
  /// (viaggio precedente completato) o si trova in un'altra casa per qualsiasi
  /// motivo, la query lo ignora senza effetti collaterali.
  ///
  /// Azzera anche [spaceId]: gli oggetti arrivano nel pool generale della casa
  /// di destinazione e l'utente potrà assegnarli a uno spazio in seguito.
  /// Se [spaceId] è fornito, gli oggetti arrivano direttamente a quello spazio.
  Future<void> moveItemsToHouse(
    List<String> itemIds,
    String fromHouseId,
    String toHouseId, {
    String? spaceId,
  }) async {
    if (itemIds.isEmpty) return;
    await (update(
      items,
    )..where((t) => t.id.isIn(itemIds) & t.houseId.equals(fromHouseId))).write(
      ItemsCompanion(
        houseId: Value(toHouseId),
        spaceId: Value(spaceId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
