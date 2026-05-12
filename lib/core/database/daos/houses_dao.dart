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

  /// Inserisce una nuova casa
  Future<int> insertHouse(HousesCompanion house) {
    return into(houses).insert(house);
  }

  /// Aggiorna una casa esistente
  Future<bool> updateHouse(HousesCompanion house) {
    return update(houses).replace(house);
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
      await (update(items)
            ..where((i) => i.houseId.equals(id) & i.isDeleted.equals(false)))
          .write(
        ItemsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );

      // Cascade soft-delete: spazi della casa
      await (update(spaces)
            ..where((s) => s.houseId.equals(id) & s.isDeleted.equals(false)))
          .write(
        SpacesCompanion(isDeleted: const Value(true), updatedAt: Value(now)),
      );

      // Cascade soft-delete: bagagli della casa
      await (update(luggages)
            ..where((l) => l.houseId.equals(id) & l.isDeleted.equals(false)))
          .write(
        LuggagesCompanion(isDeleted: const Value(true), updatedAt: Value(now)),
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

  /// Recovery: re-queues soft-deleted records stuck as "synced".
  Future<int> markDeletedAsPendingSync() {
    return (update(houses)
          ..where(
            (h) =>
                h.isDeleted.equals(true) &
                h.syncStatus.equalsValue(SyncStatus.synced),
          ))
        .write(
      const HousesCompanion(
        syncStatus: Value(SyncStatus.pendingUpdate),
      ),
    );
  }

  /// Returns houses pending sync: syncStatus != synced AND retries below limit.
  Future<List<House>> getPendingSyncHouses({int maxRetries = 5}) {
    final now = DateTime.now();
    return (select(houses)
          ..where(
            (h) =>
                h.syncStatus.equalsValue(SyncStatus.synced).not() &
                h.syncRetryCount.isSmallerThanValue(maxRetries) &
                (h.nextSyncAttemptAt.isNull() |
                    h.nextSyncAttemptAt.isSmallerOrEqualValue(now)),
          ))
        .get();
  }

  /// Marks a house as successfully synced with the remote server.
  Future<void> markHouseAsSynced(
    String houseId,
    DateTime serverUpdatedAt,
  ) {
    return (update(houses)..where((h) => h.id.equals(houseId))).write(
      HousesCompanion(
        syncStatus: const Value(SyncStatus.synced),
        syncRetryCount: const Value(0),
        lastSyncError: const Value(null),
        lastSyncedAt: Value(serverUpdatedAt),
        nextSyncAttemptAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Increments the retry counter and records the error message.
  Future<void> incrementSyncRetry(String houseId, String errorMessage) async {
    final house = await (select(houses)
          ..where((h) => h.id.equals(houseId)))
        .getSingleOrNull();
    if (house == null) return;

    final newRetryCount = house.syncRetryCount + 1;
    final backoffSeconds = 2 << (newRetryCount - 1); // 2, 4, 8, 16, ...
    final nextAttempt =
        DateTime.now().add(Duration(seconds: backoffSeconds));

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
