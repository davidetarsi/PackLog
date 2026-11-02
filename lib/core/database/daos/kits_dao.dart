import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/items_table.dart';
import '../tables/kit_items_table.dart';
import '../tables/kits_table.dart';
import '../tables/mixins/syncable_table.dart';
import 'sync_dao_mixin.dart';

part 'kits_dao.g.dart';

/// Un kit con le sue righe vive (kit e righe non cancellati, oggetto non
/// cancellato).
class KitWithItems {
  const KitWithItems(this.kit, this.items);

  final Kit kit;
  final List<KitItemRow> items;
}

/// DAO dei kit e delle loro righe.
///
/// Le operazioni di sincronizzazione sui kit vengono dal [SyncDaoMixin]; quelle
/// sulle righe stanno in `KitItemsDao`.
@DriftAccessor(tables: [Kits, KitItems, Items])
class KitsDao extends DatabaseAccessor<AppDatabase>
    with _$KitsDaoMixin, SyncDaoMixin<$KitsTable, Kit> {
  KitsDao(super.db);

  // ─── SyncDaoMixin column bindings ──────────────────────────────────────────
  @override
  TableInfo<$KitsTable, Kit> get $table => kits;
  @override
  GeneratedColumn<String> get $idCol => kits.id;
  @override
  GeneratedColumn<DateTime> get $updatedAtCol => kits.updatedAt;
  @override
  GeneratedColumn<int> get $syncStatusCol => kits.syncStatus;
  @override
  GeneratedColumn<int> get $retryCountCol => kits.syncRetryCount;
  @override
  GeneratedColumn<String> get $lastErrorCol => kits.lastSyncError;
  @override
  GeneratedColumn<DateTime> get $lastSyncedAtCol => kits.lastSyncedAt;
  @override
  GeneratedColumn<DateTime> get $nextAttemptAtCol => kits.nextSyncAttemptAt;
  @override
  GeneratedColumn<bool> get $isDeletedCol => kits.isDeleted;

  // ─── Lettura ────────────────────────────────────────────────────────────────

  /// I kit di una casa con le righe vive, dal più vecchio al più recente.
  ///
  /// Esclude i kit cancellati, le righe cancellate e le righe il cui oggetto è
  /// stato cancellato dalla casa.
  Stream<List<KitWithItems>> watchKitsOfHouse(String houseId) {
    return customSelect(
      'SELECT 1',
      readsFrom: {kits, kitItems, items},
    ).watch().asyncMap((_) => _loadKitsOfHouse(houseId));
  }

  Future<List<KitWithItems>> _loadKitsOfHouse(String houseId) async {
    final kitRows =
        await (select(kits)
              ..where(
                (k) => k.houseId.equals(houseId) & k.isDeleted.equals(false),
              )
              ..orderBy([(k) => OrderingTerm.asc(k.createdAt)]))
            .get();
    if (kitRows.isEmpty) return const [];

    final itemRows =
        await (select(
                kitItems,
              ).join([innerJoin(items, items.id.equalsExp(kitItems.itemId))])
              ..where(
                kitItems.kitId.isIn(kitRows.map((k) => k.id)) &
                    kitItems.isDeleted.equals(false) &
                    items.isDeleted.equals(false),
              )
              ..orderBy([OrderingTerm.asc(kitItems.createdAt)]))
            .map((row) => row.readTable(kitItems))
            .get();

    final byKit = <String, List<KitItemRow>>{};
    for (final row in itemRows) {
      byKit.putIfAbsent(row.kitId, () => []).add(row);
    }
    return [for (final k in kitRows) KitWithItems(k, byKit[k.id] ?? const [])];
  }

  /// Un kit con le righe vive, o `null` se non esiste o è cancellato.
  Future<KitWithItems?> getKitWithItems(String id) async {
    final kit =
        await (select(kits)
              ..where((k) => k.id.equals(id) & k.isDeleted.equals(false)))
            .getSingleOrNull();
    if (kit == null) return null;
    final rows = await liveRowsOfKit(id);
    return KitWithItems(kit, rows);
  }

  /// Le righe vive di un kit (riga non cancellata, oggetto non cancellato).
  Future<List<KitItemRow>> liveRowsOfKit(String kitId) {
    return (select(
            kitItems,
          ).join([innerJoin(items, items.id.equalsExp(kitItems.itemId))])
          ..where(
            kitItems.kitId.equals(kitId) &
                kitItems.isDeleted.equals(false) &
                items.isDeleted.equals(false),
          )
          ..orderBy([OrderingTerm.asc(kitItems.createdAt)]))
        .map((row) => row.readTable(kitItems))
        .get();
  }

  /// Degli [itemIds], quelli di oggetti vivi appartenenti a [houseId].
  Future<Set<String>> liveItemIdsOfHouse(
    String houseId,
    List<String> itemIds,
  ) async {
    final result = <String>{};
    for (var i = 0; i < itemIds.length; i += 500) {
      final chunk = itemIds.sublist(
        i,
        i + 500 > itemIds.length ? itemIds.length : i + 500,
      );
      final rows =
          await (select(items)..where(
                (t) =>
                    t.id.isIn(chunk) &
                    t.houseId.equals(houseId) &
                    t.isDeleted.equals(false),
              ))
              .get();
      result.addAll(rows.map((r) => r.id));
    }
    return result;
  }

  /// Quanti kit vivi ha una casa.
  Future<int> countLiveKitsOfHouse(String houseId) async {
    final count = kits.id.count();
    final query = selectOnly(kits)
      ..addColumns([count])
      ..where(kits.houseId.equals(houseId) & kits.isDeleted.equals(false));
    return (await query.getSingle()).read(count) ?? 0;
  }

  // ─── Scrittura ──────────────────────────────────────────────────────────────

  /// Crea il kit, o lo aggiorna se esiste già (stesso `id`).
  ///
  /// Un kit nuovo nasce `pendingCreate`. Su uno esistente la scrittura è
  /// parziale e lo segna `pendingUpdate`, salvo che non sia mai stato spedito
  /// (`pendingCreate`), nel qual caso resta tale.
  Future<void> upsertKit(KitsCompanion kit) {
    return transaction(() async {
      final existing = await (select(
        kits,
      )..where((k) => k.id.equals(kit.id.value))).getSingleOrNull();
      if (existing == null) {
        await into(kits).insert(kit);
        return;
      }
      final status = kit.syncStatus.present
          ? kit.syncStatus
          : Value(
              existing.syncStatus == SyncStatus.pendingCreate
                  ? SyncStatus.pendingCreate
                  : SyncStatus.pendingUpdate,
            );
      await (update(kits)..where((k) => k.id.equals(kit.id.value))).write(
        kit.copyWith(
          syncStatus: status,
          updatedAt: kit.updatedAt.present
              ? kit.updatedAt
              : Value(DateTime.now()),
        ),
      );
    });
  }

  /// Soft-delete di un kit e di tutte le sue righe.
  Future<void> softDeleteKit(String id) {
    return transaction(() async {
      final now = DateTime.now();
      await (update(
        kitItems,
      )..where((r) => r.kitId.equals(id) & r.isDeleted.equals(false))).write(
        KitItemsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
      await (update(kits)..where((k) => k.id.equals(id))).write(
        KitsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Soft-delete di tutti i kit di una casa e delle loro righe: serve quando
  /// la casa viene cancellata (cascade applicativo, come per gli spazi).
  Future<void> softDeleteKitsOfHouse(String houseId) {
    return transaction(() async {
      final now = DateTime.now();
      final ids =
          await (selectOnly(kits)
                ..addColumns([kits.id])
                ..where(
                  kits.houseId.equals(houseId) & kits.isDeleted.equals(false),
                ))
              .map((r) => r.read(kits.id)!)
              .get();
      if (ids.isEmpty) return;
      await (update(
        kitItems,
      )..where((r) => r.kitId.isIn(ids) & r.isDeleted.equals(false))).write(
        KitItemsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
      await (update(kits)..where((k) => k.id.isIn(ids))).write(
        KitsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Mette un oggetto nel kit, o ne cambia le copie.
  ///
  /// Una riga sola per coppia (kit, oggetto): se ne esiste una (anche
  /// cancellata) la si riattiva e se ne tiene l'`id`, altrimenti si inserisce
  /// [row].
  Future<void> upsertKitItem(KitItemsCompanion row) {
    return transaction(() async {
      final existing =
          await (select(kitItems)..where(
                (r) =>
                    r.kitId.equals(row.kitId.value) &
                    r.itemId.equals(row.itemId.value),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await into(kitItems).insert(row);
        return;
      }
      await (update(kitItems)..where((r) => r.id.equals(existing.id))).write(
        KitItemsCompanion(
          copies: row.copies,
          isDeleted: const Value(false),
          syncStatus: Value(
            existing.syncStatus == SyncStatus.pendingCreate
                ? SyncStatus.pendingCreate
                : SyncStatus.pendingUpdate,
          ),
          updatedAt: row.updatedAt.present
              ? row.updatedAt
              : Value(DateTime.now()),
        ),
      );
    });
  }

  /// Soft-delete della riga di un oggetto in un kit.
  Future<void> softDeleteKitItem(String kitId, String itemId) {
    return (update(kitItems)..where(
          (r) =>
              r.kitId.equals(kitId) &
              r.itemId.equals(itemId) &
              r.isDeleted.equals(false),
        ))
        .write(
          KitItemsCompanion(
            isDeleted: const Value(true),
            syncStatus: const Value(SyncStatus.pendingUpdate),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Toglie gli oggetti da tutti i kit (soft-delete delle righe): serve
  /// quando gli oggetti cambiano casa.
  ///
  /// Non si usa per la cancellazione degli oggetti: le loro righe restano
  /// vive e [watchKitsOfHouse] le nasconde con il join, così ripristinare
  /// un oggetto lo riporta nei suoi kit senza altro lavoro.
  Future<void> softDeleteItemsEverywhere(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final now = DateTime.now();
    await transaction(() async {
      // A blocchi, per restare sotto il limite di variabili di SQLite.
      for (var i = 0; i < itemIds.length; i += 500) {
        final chunk = itemIds.sublist(
          i,
          i + 500 > itemIds.length ? itemIds.length : i + 500,
        );
        await (update(kitItems)
              ..where((r) => r.itemId.isIn(chunk) & r.isDeleted.equals(false)))
            .write(
              KitItemsCompanion(
                isDeleted: const Value(true),
                syncStatus: const Value(SyncStatus.pendingUpdate),
                updatedAt: Value(now),
              ),
            );
      }
    });
  }

  // === SYNC OPERATIONS ===

  /// Ottiene un kit per ID indipendentemente dal flag isDeleted.
  /// Usato dal sync per rilevare record locali prima di insert/update da remoto.
  Future<Kit?> findKitById(String id) {
    return (select(kits)..where((k) => k.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce un kit arrivato dal cloud.
  Future<int> insertKit(KitsCompanion kit) => into(kits).insert(kit);

  /// Aggiorna un kit con scrittura parziale (come `SpacesDao.updateSpace`).
  Future<bool> updateKit(KitsCompanion kit) async {
    final companion = kit.syncStatus.present
        ? kit
        : kit.copyWith(syncStatus: const Value(SyncStatus.pendingUpdate));
    final count = await (update(
      kits,
    )..where((k) => k.id.equals(kit.id.value))).write(companion);
    return count > 0;
  }
}
