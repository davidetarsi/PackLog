import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/luggages_table.dart';
import '../tables/mixins/syncable_table.dart';
import '../tables/trip_luggage_entries_table.dart';

part 'luggages_dao.g.dart';

/// DAO per le operazioni CRUD sui bagagli.
@DriftAccessor(tables: [Luggages, TripLuggageEntries])
class LuggagesDao extends DatabaseAccessor<AppDatabase>
    with _$LuggagesDaoMixin {
  LuggagesDao(super.db);

  /// Ottiene tutti i bagagli non eliminati
  Future<List<Luggage>> getAllLuggages() =>
      (select(luggages)..where((l) => l.isDeleted.equals(false))).get();

  /// Ottiene tutti i bagagli non eliminati di una casa specifica
  Future<List<Luggage>> getLuggagesByHouse(String houseId) {
    return (select(luggages)
          ..where((l) => l.houseId.equals(houseId) & l.isDeleted.equals(false)))
        .get();
  }

  /// Ottiene tutti i bagagli non eliminati di una casa come stream
  Stream<List<Luggage>> watchLuggagesByHouse(String houseId) {
    return (select(luggages)
          ..where((l) => l.houseId.equals(houseId) & l.isDeleted.equals(false)))
        .watch();
  }

  /// Ottiene un bagaglio per ID (solo se non eliminato)
  Future<Luggage?> getLuggageById(String id) {
    return (select(luggages)
          ..where((l) => l.id.equals(id) & l.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserisce un nuovo bagaglio
  Future<int> insertLuggage(LuggagesCompanion luggage) {
    return into(luggages).insert(luggage);
  }

  /// Aggiorna un bagaglio esistente.
  ///
  /// Usa `.write()` parziale + `syncStatus = pendingUpdate`. Vedi
  /// [HousesDao.updateHouse] per la motivazione.
  Future<bool> updateLuggage(LuggagesCompanion luggage) async {
    final companion = luggage.syncStatus.present
        ? luggage
        : luggage.copyWith(syncStatus: const Value(SyncStatus.pendingUpdate));
    final count = await (update(
      luggages,
    )..where((l) => l.id.equals(luggage.id.value))).write(companion);
    return count > 0;
  }

  /// Soft-delete di un bagaglio.
  ///
  /// Le entry in [TripLuggageEntries] restano fisicamente nel DB (junction
  /// table senza isDeleted) ma diventano invisibili nelle query di lettura
  /// perché il JOIN filtra i bagagli con [isDeleted = false].
  Future<int> deleteLuggage(String id) {
    return (update(luggages)..where((l) => l.id.equals(id))).write(
      LuggagesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Ottiene i bagagli non eliminati associati a un viaggio tramite junction table.
  Future<List<Luggage>> getLuggagesByTrip(String tripId) async {
    final query =
        select(luggages).join([
          innerJoin(
            tripLuggageEntries,
            tripLuggageEntries.luggageId.equalsExp(luggages.id),
          ),
        ])..where(
          tripLuggageEntries.tripId.equals(tripId) &
              luggages.isDeleted.equals(false),
        );

    final results = await query.get();
    return results.map((row) => row.readTable(luggages)).toList();
  }

  /// Associa un bagaglio a un viaggio (inserisce entry nella junction table).
  Future<void> linkLuggageToTrip(String tripId, String luggageId) async {
    await into(tripLuggageEntries).insert(
      TripLuggageEntriesCompanion.insert(tripId: tripId, luggageId: luggageId),
    );
  }

  /// Rimuove l'associazione tra un bagaglio e un viaggio.
  Future<void> unlinkLuggageFromTrip(String tripId, String luggageId) async {
    await (delete(tripLuggageEntries)..where(
          (entry) =>
              entry.tripId.equals(tripId) & entry.luggageId.equals(luggageId),
        ))
        .go();
  }

  /// Sostituisce tutti i bagagli associati a un viaggio.
  ///
  /// Esegue in transaction:
  /// 1. Elimina tutte le entry esistenti per il trip
  /// 2. Inserisce le nuove entry
  Future<void> replaceTripLuggages(
    String tripId,
    List<String> luggageIds,
  ) async {
    await transaction(() async {
      await (delete(
        tripLuggageEntries,
      )..where((entry) => entry.tripId.equals(tripId))).go();

      if (luggageIds.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            tripLuggageEntries,
            luggageIds
                .map(
                  (luggageId) => TripLuggageEntriesCompanion.insert(
                    tripId: tripId,
                    luggageId: luggageId,
                  ),
                )
                .toList(),
          );
        });
      }
    });
  }

  /// Conta il numero di bagagli non eliminati in una casa
  Future<int> countLuggagesByHouse(String houseId) async {
    final query = selectOnly(luggages)
      ..addColumns([luggages.id.count()])
      ..where(
        luggages.houseId.equals(houseId) & luggages.isDeleted.equals(false),
      );

    final result = await query.getSingleOrNull();
    return result?.read(luggages.id.count()) ?? 0;
  }

  // === SYNC OPERATIONS ===

  /// Ottiene un bagaglio per ID indipendentemente dal flag isDeleted.
  /// Usato dal sync per rilevare record locali prima di insert/update da remoto.
  Future<Luggage?> findLuggageById(String id) {
    return (select(luggages)..where((l) => l.id.equals(id))).getSingleOrNull();
  }

  /// Physical DELETE after successful sync of a soft-deleted record.
  Future<void> purgeLuggage(String id) {
    return (delete(luggages)..where((l) => l.id.equals(id))).go();
  }

  /// Wipes ALL rows. Vedi [HousesDao.wipeAll].
  Future<void> wipeAll() => delete(luggages).go();

  /// Recovery: re-queues soft-deleted records stuck as "synced".
  Future<int> markDeletedAsPendingSync() {
    return (update(luggages)..where(
          (l) =>
              l.isDeleted.equals(true) &
              l.syncStatus.equalsValue(SyncStatus.synced),
        ))
        .write(
          const LuggagesCompanion(syncStatus: Value(SyncStatus.pendingUpdate)),
        );
  }

  /// Returns luggages pending sync: syncStatus != synced AND retries below limit.
  Future<List<Luggage>> getPendingSyncLuggages({int maxRetries = 5}) {
    final now = DateTime.now();
    return (select(luggages)..where(
          (l) =>
              l.syncStatus.equalsValue(SyncStatus.synced).not() &
              l.syncRetryCount.isSmallerThanValue(maxRetries) &
              (l.nextSyncAttemptAt.isNull() |
                  l.nextSyncAttemptAt.isSmallerOrEqualValue(now)),
        ))
        .get();
  }

  Future<int> countUnsynced() async {
    final rows = await (select(
      luggages,
    )..where((l) => l.syncStatus.equalsValue(SyncStatus.synced).not())).get();
    return rows.length;
  }

  /// Applica `serverUpdatedAt` sia a `updatedAt` (pivot LWW) sia a
  /// `lastSyncedAt`. Vedi [HousesDao.markHouseAsSynced] per il rationale e
  /// la semantica di [localUpdatedAt] (race condition guard).
  Future<void> markLuggageAsSynced(
    String luggageId,
    DateTime serverUpdatedAt, {
    required DateTime localUpdatedAt,
  }) {
    return (update(luggages)
          ..where(
            (l) =>
                l.id.equals(luggageId) & l.updatedAt.equals(localUpdatedAt),
          ))
        .write(
      LuggagesCompanion(
        updatedAt: Value(serverUpdatedAt),
        syncStatus: const Value(SyncStatus.synced),
        syncRetryCount: const Value(0),
        lastSyncError: const Value(null),
        lastSyncedAt: Value(serverUpdatedAt),
        nextSyncAttemptAt: const Value(null),
      ),
    );
  }

  /// Resets retry state on records bloccati oltre soglia. Vedi
  /// [HousesDao.resetSyncRetries] per il contratto.
  Future<int> resetSyncRetries() {
    return (update(
      luggages,
    )..where((l) => l.syncRetryCount.isBiggerThanValue(0))).write(
      const LuggagesCompanion(
        syncRetryCount: Value(0),
        lastSyncError: Value(null),
        nextSyncAttemptAt: Value(null),
      ),
    );
  }

  Future<void> incrementSyncRetry(String luggageId, String errorMessage) async {
    final luggage = await (select(
      luggages,
    )..where((l) => l.id.equals(luggageId))).getSingleOrNull();
    if (luggage == null) return;

    final newRetryCount = luggage.syncRetryCount + 1;
    final backoffSeconds = 2 << (newRetryCount - 1);
    final nextAttempt = DateTime.now().add(Duration(seconds: backoffSeconds));

    await (update(luggages)..where((l) => l.id.equals(luggageId))).write(
      LuggagesCompanion(
        syncRetryCount: Value(newRetryCount),
        lastSyncError: Value(errorMessage),
        nextSyncAttemptAt: Value(nextAttempt),
        // NB: niente updatedAt — è il pivot LWW, il retry bookkeeping
        // non deve renderlo artificialmente "più nuovo" di edit remoti.
      ),
    );
  }
}
