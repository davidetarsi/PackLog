import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/mixins/syncable_table.dart';
import '../tables/houses_table.dart';
import '../tables/items_table.dart';
import '../tables/spaces_table.dart';
import '../tables/luggages_table.dart';

part 'houses_dao.g.dart';

/// DAO per le operazioni CRUD sulle case.
@DriftAccessor(tables: [Houses, Items, Spaces, Luggages])
class HousesDao extends DatabaseAccessor<AppDatabase> with _$HousesDaoMixin {
  HousesDao(super.db);

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

  /// Inserisce multiple case (per migrazione)
  Future<void> insertMultipleHouses(List<HousesCompanion> housesList) async {
    await batch((batch) {
      batch.insertAll(houses, housesList);
    });
  }

  // === SYNC OPERATIONS ===

  /// Physical DELETE after successful sync of a soft-deleted record.
  Future<void> purgeHouse(String id) {
    return (delete(houses)..where((h) => h.id.equals(id))).go();
  }

  /// Wipes ALL rows. Used at account switch to clear the previous user's
  /// data before pulling the new one. `ON DELETE CASCADE` su items/spaces/
  /// luggages e su trip_*_entries propaga la cancellazione, ma per coerenza
  /// gli altri DAO espongono anch'essi `wipeAll()` e il chiamante (SyncService)
  /// li orchestra in ordine.
  Future<void> wipeAll() => delete(houses).go();

  /// Recovery: re-queues soft-deleted records stuck as "synced".
  Future<int> markDeletedAsPendingSync() {
    return (update(houses)..where(
          (h) =>
              h.isDeleted.equals(true) &
              h.syncStatus.equalsValue(SyncStatus.synced),
        ))
        .write(
          const HousesCompanion(syncStatus: Value(SyncStatus.pendingUpdate)),
        );
  }

  /// Returns houses pending sync: syncStatus != synced AND retries below limit.
  Future<List<House>> getPendingSyncHouses({int maxRetries = 5}) {
    final now = DateTime.now();
    return (select(houses)..where(
          (h) =>
              h.syncStatus.equalsValue(SyncStatus.synced).not() &
              h.syncRetryCount.isSmallerThanValue(maxRetries) &
              (h.nextSyncAttemptAt.isNull() |
                  h.nextSyncAttemptAt.isSmallerOrEqualValue(now)),
        ))
        .get();
  }

  /// Marks a house as successfully synced with the remote server.
  ///
  /// Non aggiorna `updatedAt`: è il pivot del Last-Write-Wins; un bump qui
  /// renderebbe il timestamp locale posteriore a quello pushato al server
  /// e farebbe perdere edit concorrenti da altri device.
  Future<void> markHouseAsSynced(String houseId, DateTime serverUpdatedAt) {
    return (update(houses)..where((h) => h.id.equals(houseId))).write(
      HousesCompanion(
        syncStatus: const Value(SyncStatus.synced),
        syncRetryCount: const Value(0),
        lastSyncError: const Value(null),
        lastSyncedAt: Value(serverUpdatedAt),
        nextSyncAttemptAt: const Value(null),
      ),
    );
  }

  /// Resets retry state on records that were giving up: dopo 5 fallimenti
  /// consecutivi `getPendingSyncHouses` li nasconde finché `syncRetryCount`
  /// non torna sotto soglia. Tipicamente chiamato su `connectivity_restored`
  /// o all'avvio dell'app per dare una nuova chance ai record bloccati.
  ///
  /// Returns: number of rows reset.
  Future<int> resetSyncRetries() {
    return (update(houses)..where((h) => h.syncRetryCount.isBiggerThanValue(0)))
        .write(
          const HousesCompanion(
            syncRetryCount: Value(0),
            lastSyncError: Value(null),
            nextSyncAttemptAt: Value(null),
          ),
        );
  }

  /// Increments the retry counter and records the error message.
  Future<void> incrementSyncRetry(String houseId, String errorMessage) async {
    final house = await (select(
      houses,
    )..where((h) => h.id.equals(houseId))).getSingleOrNull();
    if (house == null) return;

    final newRetryCount = house.syncRetryCount + 1;
    final backoffSeconds = 2 << (newRetryCount - 1); // 2, 4, 8, 16, ...
    final nextAttempt = DateTime.now().add(Duration(seconds: backoffSeconds));

    await (update(houses)..where((h) => h.id.equals(houseId))).write(
      HousesCompanion(
        syncRetryCount: Value(newRetryCount),
        lastSyncError: Value(errorMessage),
        nextSyncAttemptAt: Value(nextAttempt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
