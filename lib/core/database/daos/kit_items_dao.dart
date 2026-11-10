import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/kit_items_table.dart';
import '../tables/mixins/syncable_table.dart';
import 'sync_dao_mixin.dart';

part 'kit_items_dao.g.dart';

/// Operazioni di sincronizzazione sulle righe dei kit.
///
/// Le operazioni di dominio (aggiungere, togliere, riattivare) stanno in
/// `KitsDao`, che vede insieme kit e righe; qui c'è solo ciò che serve al
/// `SyncService`, che tratta `kit_items` come ogni altra tabella (il
/// `SyncDaoMixin` lavora su una tabella sola).
@DriftAccessor(tables: [KitItems])
class KitItemsDao extends DatabaseAccessor<AppDatabase>
    with _$KitItemsDaoMixin, SyncDaoMixin<$KitItemsTable, KitItemRow> {
  KitItemsDao(super.db);

  // ─── SyncDaoMixin column bindings ──────────────────────────────────────────
  @override
  TableInfo<$KitItemsTable, KitItemRow> get $table => kitItems;
  @override
  GeneratedColumn<String> get $idCol => kitItems.id;
  @override
  GeneratedColumn<DateTime> get $updatedAtCol => kitItems.updatedAt;
  @override
  GeneratedColumn<int> get $syncStatusCol => kitItems.syncStatus;
  @override
  GeneratedColumn<int> get $retryCountCol => kitItems.syncRetryCount;
  @override
  GeneratedColumn<String> get $lastErrorCol => kitItems.lastSyncError;
  @override
  GeneratedColumn<DateTime> get $lastSyncedAtCol => kitItems.lastSyncedAt;
  @override
  GeneratedColumn<DateTime> get $nextAttemptAtCol => kitItems.nextSyncAttemptAt;
  @override
  GeneratedColumn<bool> get $isDeletedCol => kitItems.isDeleted;

  /// Ottiene una riga per ID indipendentemente dal flag isDeleted.
  /// Usato dal sync per rilevare record locali prima di insert/update da remoto.
  Future<KitItemRow?> findKitItemById(String id) {
    return (select(kitItems)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Ottiene la riga di una coppia (kit, oggetto), anche se cancellata.
  Future<KitItemRow?> findKitItemByPair(String kitId, String itemId) {
    return (select(kitItems)
          ..where((r) => r.kitId.equals(kitId) & r.itemId.equals(itemId)))
        .getSingleOrNull();
  }

  /// Inserisce una riga arrivata dal cloud.
  Future<int> insertKitItem(KitItemsCompanion row) =>
      into(kitItems).insert(row);

  /// Aggiorna una riga con scrittura parziale. Se [row] non porta uno
  /// `syncStatus`, la riga resta da sincronizzare (`pendingUpdate`).
  Future<bool> updateKitItem(KitItemsCompanion row) async {
    final companion = row.syncStatus.present
        ? row
        : row.copyWith(syncStatus: const Value(SyncStatus.pendingUpdate));
    final count = await (update(
      kitItems,
    )..where((r) => r.id.equals(row.id.value))).write(companion);
    return count > 0;
  }
}
