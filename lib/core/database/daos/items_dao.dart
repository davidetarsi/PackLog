import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/items_table.dart';
import '../tables/mixins/syncable_table.dart';
import 'sync_dao_mixin.dart';

part 'items_dao.g.dart';

/// DAO per le operazioni CRUD sugli oggetti.
@DriftAccessor(tables: [Items])
class ItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ItemsDaoMixin, SyncDaoMixin<$ItemsTable, Item> {
  ItemsDao(super.db);

  // ─── SyncDaoMixin column bindings ──────────────────────────────────────────
  @override
  TableInfo<$ItemsTable, Item> get $table => items;
  @override
  GeneratedColumn<String> get $idCol => items.id;
  @override
  GeneratedColumn<DateTime> get $updatedAtCol => items.updatedAt;
  @override
  GeneratedColumn<int> get $syncStatusCol => items.syncStatus;
  @override
  GeneratedColumn<int> get $retryCountCol => items.syncRetryCount;
  @override
  GeneratedColumn<String> get $lastErrorCol => items.lastSyncError;
  @override
  GeneratedColumn<DateTime> get $lastSyncedAtCol => items.lastSyncedAt;
  @override
  GeneratedColumn<DateTime> get $nextAttemptAtCol => items.nextSyncAttemptAt;
  @override
  GeneratedColumn<bool> get $isDeletedCol => items.isDeleted;

  /// Ottiene tutti gli oggetti non eliminati
  Future<List<Item>> getAllItems() =>
      (select(items)..where((i) => i.isDeleted.equals(false))).get();

  /// Ottiene tutti gli oggetti non eliminati come stream
  Stream<List<Item>> watchAllItems() =>
      (select(items)..where((i) => i.isDeleted.equals(false))).watch();

  /// Ottiene gli oggetti non eliminati di una casa specifica, ordinati
  /// alfabeticamente per nome (case-insensitive).
  Future<List<Item>> getItemsByHouseId(String houseId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.isDeleted.equals(false))
          ..orderBy([(i) => OrderingTerm(expression: i.name.lower())]))
        .get();
  }

  /// Ottiene gli oggetti non eliminati di una casa come stream, ordinati
  /// alfabeticamente per nome (case-insensitive).
  Stream<List<Item>> watchItemsByHouseId(String houseId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.isDeleted.equals(false))
          ..orderBy([(i) => OrderingTerm(expression: i.name.lower())]))
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

  /// Aggiorna un oggetto esistente.
  ///
  /// Usa `.write()` parziale: preserva i campi sync che il chiamante omette
  /// (`lastSyncedAt`, `syncRetryCount`, ecc.) e forza `syncStatus = pendingUpdate`
  /// per garantirne la propagazione al cloud.
  Future<bool> updateItem(ItemsCompanion item) async {
    final companion = item.syncStatus.present
        ? item
        : item.copyWith(syncStatus: const Value(SyncStatus.pendingUpdate));
    final count = await (update(
      items,
    )..where((i) => i.id.equals(item.id.value))).write(companion);
    return count > 0;
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

  // === SYNC OPERATIONS (delegated to SyncDaoMixin) ===
  // purgeRecord, wipeAll, markDeletedAsPendingSync, getPendingSyncRecords,
  // countUnsynced, markAsSynced, resetSyncRetries, incrementSyncRetry

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
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
