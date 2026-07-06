import 'package:drift/drift.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import '../database.dart';
import '../tables/spaces_table.dart';
import '../tables/items_table.dart';
import 'sync_dao_mixin.dart';

part 'spaces_dao.g.dart';

/// DAO per le operazioni CRUD sugli spazi/armadi.
@DriftAccessor(tables: [Spaces, Items])
class SpacesDao extends DatabaseAccessor<AppDatabase>
    with _$SpacesDaoMixin, SyncDaoMixin<$SpacesTable, Space> {
  SpacesDao(super.db);

  // ─── SyncDaoMixin column bindings ──────────────────────────────────────────
  @override
  TableInfo<$SpacesTable, Space> get $table => spaces;
  @override
  GeneratedColumn<String> get $idCol => spaces.id;
  @override
  GeneratedColumn<DateTime> get $updatedAtCol => spaces.updatedAt;
  @override
  GeneratedColumn<int> get $syncStatusCol => spaces.syncStatus;
  @override
  GeneratedColumn<int> get $retryCountCol => spaces.syncRetryCount;
  @override
  GeneratedColumn<String> get $lastErrorCol => spaces.lastSyncError;
  @override
  GeneratedColumn<DateTime> get $lastSyncedAtCol => spaces.lastSyncedAt;
  @override
  GeneratedColumn<DateTime> get $nextAttemptAtCol => spaces.nextSyncAttemptAt;
  @override
  GeneratedColumn<bool> get $isDeletedCol => spaces.isDeleted;

  /// Ottiene tutti gli spazi non eliminati
  Future<List<Space>> getAllSpaces() =>
      (select(spaces)..where((s) => s.isDeleted.equals(false))).get();

  /// Ottiene tutti gli spazi non eliminati di una casa specifica
  Future<List<Space>> getSpacesByHouse(String houseId) {
    return (select(spaces)
          ..where((s) => s.houseId.equals(houseId) & s.isDeleted.equals(false)))
        .get();
  }

  /// Ottiene tutti gli spazi non eliminati di una casa come stream
  Stream<List<Space>> watchSpacesByHouse(String houseId) {
    return (select(spaces)
          ..where((s) => s.houseId.equals(houseId) & s.isDeleted.equals(false)))
        .watch();
  }

  /// Ottiene uno spazio per ID (solo se non eliminato)
  Future<Space?> getSpaceById(String id) {
    return (select(spaces)
          ..where((s) => s.id.equals(id) & s.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserisce un nuovo spazio
  Future<int> insertSpace(SpacesCompanion space) {
    return into(spaces).insert(space);
  }

  /// Aggiorna uno spazio esistente.
  ///
  /// Usa `.write()` parziale + `syncStatus = pendingUpdate`. Vedi
  /// [HousesDao.updateHouse] per la motivazione.
  Future<bool> updateSpace(SpacesCompanion space) async {
    final companion = space.syncStatus.present
        ? space
        : space.copyWith(syncStatus: const Value(SyncStatus.pendingUpdate));
    final count = await (update(
      spaces,
    )..where((s) => s.id.equals(space.id.value))).write(companion);
    return count > 0;
  }

  /// Soft-delete di uno spazio con ripristino del pool degli item.
  ///
  /// Sostituisce DELETE fisica (con ON DELETE SET NULL sulla FK) con una
  /// transazione che:
  /// 1. Riporta nel pool generale (spaceId → null) tutti gli item *non eliminati*
  ///    che si trovano in questo spazio.
  /// 2. Imposta [isDeleted = true] sullo spazio.
  Future<int> deleteSpace(String id) async {
    return transaction(() async {
      // Ripristino pool: gli item dello spazio tornano nel pool generale della casa.
      // Agisce solo sugli item non già eliminati per evitare write inutili.
      await (update(
        items,
      )..where((i) => i.spaceId.equals(id) & i.isDeleted.equals(false))).write(
        ItemsCompanion(
          spaceId: const Value(null),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return (update(spaces)..where((s) => s.id.equals(id))).write(
        SpacesCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Conta il numero di spazi non eliminati in una casa
  Future<int> countSpacesByHouse(String houseId) async {
    final query = selectOnly(spaces)
      ..addColumns([spaces.id.count()])
      ..where(spaces.houseId.equals(houseId) & spaces.isDeleted.equals(false));

    final result = await query.getSingleOrNull();
    return result?.read(spaces.id.count()) ?? 0;
  }

  // === SYNC OPERATIONS ===

  /// Ottiene uno spazio per ID indipendentemente dal flag isDeleted.
  /// Usato dal sync per rilevare record locali prima di insert/update da remoto.
  Future<Space?> findSpaceById(String id) {
    return (select(spaces)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  // purgeRecord, wipeAll, markDeletedAsPendingSync, getPendingSyncRecords,
  // countUnsynced, markAsSynced, resetSyncRetries, incrementSyncRetry
  // → delegated to SyncDaoMixin
}
