import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/mixins/syncable_table.dart';
import '../tables/houses_table.dart';
import '../tables/items_table.dart';
import '../tables/spaces_table.dart';
import '../tables/luggages_table.dart';
import 'sync_dao_mixin.dart';

part 'houses_dao.g.dart';

/// DAO per le operazioni CRUD sulle case.
@DriftAccessor(tables: [Houses, Items, Spaces, Luggages])
class HousesDao extends DatabaseAccessor<AppDatabase>
    with _$HousesDaoMixin, SyncDaoMixin<$HousesTable, House> {
  HousesDao(super.db);

  // ─── SyncDaoMixin column bindings ──────────────────────────────────────────
  @override
  TableInfo<$HousesTable, House> get $table => houses;
  @override
  GeneratedColumn<String> get $idCol => houses.id;
  @override
  GeneratedColumn<DateTime> get $updatedAtCol => houses.updatedAt;
  @override
  GeneratedColumn<int> get $syncStatusCol => houses.syncStatus;
  @override
  GeneratedColumn<int> get $retryCountCol => houses.syncRetryCount;
  @override
  GeneratedColumn<String> get $lastErrorCol => houses.lastSyncError;
  @override
  GeneratedColumn<DateTime> get $lastSyncedAtCol => houses.lastSyncedAt;
  @override
  GeneratedColumn<DateTime> get $nextAttemptAtCol => houses.nextSyncAttemptAt;
  @override
  GeneratedColumn<bool> get $isDeletedCol => houses.isDeleted;

  /// Ottiene tutte le case non eliminate
  Future<List<House>> getAllHouses() =>
      (select(houses)..where((h) => h.isDeleted.equals(false))).get();

  /// Ottiene tutte le case non eliminate come stream
  Stream<List<House>> watchAllHouses() =>
      (select(houses)..where((h) => h.isDeleted.equals(false))).watch();

  /// Ottiene una casa per ID (solo se non eliminata)
  Future<House?> getHouseById(String id) {
    return (select(houses)
          ..where((h) => h.id.equals(id) & h.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Ottiene una casa per ID indipendentemente dal flag isDeleted.
  /// Usato dal sync per rilevare record locali prima di insert/update da remoto.
  Future<House?> findHouseById(String id) {
    return (select(houses)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce una nuova casa
  Future<int> insertHouse(HousesCompanion house) {
    return into(houses).insert(house);
  }

  /// Creates a house and its initial items atomically (for onboarding default house).
  Future<void> createHouseWithItems(
    HousesCompanion house,
    List<ItemsCompanion> initialItems,
  ) {
    return transaction(() async {
      await into(houses).insert(house);
      if (initialItems.isNotEmpty) {
        await batch((b) => b.insertAll(items, initialItems));
      }
    });
  }

  /// Aggiorna una casa esistente.
  ///
  /// Usa `.write()` parziale sui soli campi del companion (non `.replace()`):
  /// preserva `lastSyncedAt`, `syncRetryCount`, ecc. che il chiamante non
  /// imposta. Forza `syncStatus = pendingUpdate` così che il record venga
  /// rispinto al cloud (sovrascrive eventuali valori del companion).
  Future<bool> updateHouse(HousesCompanion house) async {
    // Solo se il chiamante non ha settato esplicitamente syncStatus
    // forziamo pendingUpdate (caso tipico: repository = mutazione utente).
    // Se l'ha settato lo rispettiamo (es. test integration che vogliono
    // preservare pendingCreate sul primo edit pre-sync).
    final companion = house.syncStatus.present
        ? house
        : house.copyWith(syncStatus: const Value(SyncStatus.pendingUpdate));
    final count = await (update(
      houses,
    )..where((h) => h.id.equals(house.id.value))).write(companion);
    return count > 0;
  }

  /// Soft-delete di una casa con cascade manuale su Items, Spaces e Luggages.
  ///
  /// Sostituisce la DELETE fisica (con CASCADE SQLite) con una transazione
  /// che imposta [isDeleted = true] sulla casa e su tutti i record dipendenti
  /// non già eliminati. Il database mantiene le righe per consentire la
  /// propagazione al cloud prima della purga definitiva.
  Future<int> deleteHouse(String id) async {
    return transaction(() async {
      final now = DateTime.now();

      // Cascade soft-delete: items della casa (con syncStatus per propagare al cloud)
      await (update(
        items,
      )..where((i) => i.houseId.equals(id) & i.isDeleted.equals(false))).write(
        ItemsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );

      // Cascade soft-delete: spazi della casa (con syncStatus per propagare al cloud)
      await (update(
        spaces,
      )..where((s) => s.houseId.equals(id) & s.isDeleted.equals(false))).write(
        SpacesCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );

      // Cascade soft-delete: bagagli della casa (con syncStatus per propagare al cloud)
      await (update(
        luggages,
      )..where((l) => l.houseId.equals(id) & l.isDeleted.equals(false))).write(
        LuggagesCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );

      // Soft-delete della casa stessa
      return (update(houses)..where((h) => h.id.equals(id))).write(
        HousesCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Imposta una casa come principale in modo atomico.
  ///
  /// Usa 4 write in una transazione anziché N update in loop (anti-pattern CLAUDE.md).
  /// [SyncStatus.pendingCreate] viene preservato: una casa creata offline ma non
  /// ancora sincronizzata non viene degradata a [pendingUpdate] (che causerebbe un
  /// PATCH su un record inesistente sul server → sync failure).
  Future<void> setPrimaryHouse(String newPrimaryId) {
    return transaction(() async {
      final now = DateTime.now();

      // 1a. Clear: righe synced/pendingUpdate → rimuovi isPrimary + marca pendingUpdate
      await (update(houses)..where(
            (h) =>
                h.isPrimary.equals(true) &
                h.id.equals(newPrimaryId).not() &
                h.isDeleted.equals(false) &
                h.syncStatus.equalsValue(SyncStatus.pendingCreate).not(),
          ))
          .write(
            HousesCompanion(
              isPrimary: const Value(false),
              syncStatus: const Value(SyncStatus.pendingUpdate),
              updatedAt: Value(now),
            ),
          );

      // 1b. Clear: righe pendingCreate → rimuovi solo isPrimary, syncStatus invariato
      await (update(houses)..where(
            (h) =>
                h.isPrimary.equals(true) &
                h.id.equals(newPrimaryId).not() &
                h.isDeleted.equals(false) &
                h.syncStatus.equalsValue(SyncStatus.pendingCreate),
          ))
          .write(
            HousesCompanion(
              isPrimary: const Value(false),
              updatedAt: Value(now),
            ),
          );

      // 2a. Set: riga target synced/pendingUpdate → imposta isPrimary + marca pendingUpdate
      await (update(houses)..where(
            (h) =>
                h.id.equals(newPrimaryId) &
                h.isDeleted.equals(false) &
                h.syncStatus.equalsValue(SyncStatus.pendingCreate).not(),
          ))
          .write(
            HousesCompanion(
              isPrimary: const Value(true),
              syncStatus: const Value(SyncStatus.pendingUpdate),
              updatedAt: Value(now),
            ),
          );

      // 2b. Set: riga target pendingCreate → imposta solo isPrimary, syncStatus invariato
      await (update(houses)..where(
            (h) =>
                h.id.equals(newPrimaryId) &
                h.isDeleted.equals(false) &
                h.syncStatus.equalsValue(SyncStatus.pendingCreate),
          ))
          .write(
            HousesCompanion(
              isPrimary: const Value(true),
              updatedAt: Value(now),
            ),
          );
    });
  }

  /// Inserisce multiple case (per migrazione)
  Future<void> insertMultipleHouses(List<HousesCompanion> housesList) async {
    await batch((batch) {
      batch.insertAll(houses, housesList);
    });
  }

  // === SYNC OPERATIONS delegated to SyncDaoMixin ============================
  // purgeRecord, wipeAll, markDeletedAsPendingSync, getPendingSyncRecords,
  // countUnsynced, markAsSynced, resetSyncRetries, incrementSyncRetry
}
