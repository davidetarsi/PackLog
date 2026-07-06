import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/mixins/syncable_table.dart';

/// Generic [Insertable] built from a column-name → Expression map.
///
/// Allows writing partial UPDATEs across entity tables without entity-specific
/// Companion types. Keys are SQL column names (e.g. `'sync_status'`).
/// Mirrors what Drift's generated Companions do in `toColumns()`.
class _SyncInsertable<D> implements Insertable<D> {
  final Map<String, Expression> _columns;
  const _SyncInsertable(this._columns);

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => _columns;
}

/// Generic sync operations shared by all 5 entity DAOs.
///
/// Each DAO provides its table reference and column getters via the abstract
/// members; this mixin supplies identical implementations of [markAsSynced],
/// [incrementSyncRetry], [resetSyncRetries], [getPendingSyncRecords],
/// [countUnsynced], [wipeAll], [markDeletedAsPendingSync] and [purgeRecord],
/// eliminating ~100 lines × 5 of duplication.
///
/// SyncStatus is stored as int in SQLite (via `intEnum`). The mixin accesses
/// it through [SyncStatus.index] values to avoid binding to the
/// [GeneratedColumnWithTypeConverter] type — keeping column declarations
/// at the plain [GeneratedColumn<int>] level.
mixin SyncDaoMixin<T extends Table, D> on DatabaseAccessor<AppDatabase> {
  // ─── Subclasses must implement ─────────────────────────────────────────────

  TableInfo<T, D> get $table;
  GeneratedColumn<String> get $idCol;
  GeneratedColumn<DateTime> get $updatedAtCol;
  GeneratedColumn<int> get $syncStatusCol;
  GeneratedColumn<int> get $retryCountCol;
  GeneratedColumn<String> get $lastErrorCol;
  GeneratedColumn<DateTime> get $lastSyncedAtCol;
  GeneratedColumn<DateTime> get $nextAttemptAtCol;
  GeneratedColumn<bool> get $isDeletedCol;

  // ─── Generic sync operations ────────────────────────────────────────────────

  /// Physical DELETE after successful sync of a soft-deleted record.
  Future<void> purgeRecord(String id) =>
      (delete($table)..where((_) => $idCol.equals(id))).go();

  /// Wipes ALL rows. Used at account switch: SyncService orchestrates
  /// call order (items/spaces/luggages/trips before houses) so FK constraints
  /// are satisfied even without ON DELETE CASCADE on every table.
  Future<void> wipeAll() => delete($table).go();

  /// Recovery: re-queues soft-deleted records that are stuck as "synced"
  /// (e.g. after a failed purge). Called from SyncService.recoverSyncState().
  Future<int> markDeletedAsPendingSync() {
    return (update($table)
          ..where(
            (_) =>
                $isDeletedCol.equals(true) &
                $syncStatusCol.equals(SyncStatus.synced.index),
          ))
        .write(
          _SyncInsertable({
            $syncStatusCol.name: Variable<int>(SyncStatus.pendingUpdate.index),
          }),
        );
  }

  /// Returns records pending sync: syncStatus != synced AND below retry limit
  /// AND past the backoff deadline (or no backoff set).
  Future<List<D>> getPendingSyncRecords({int maxRetries = 5}) {
    final now = DateTime.now();
    return (select($table)
          ..where(
            (_) =>
                $syncStatusCol.equals(SyncStatus.synced.index).not() &
                $retryCountCol.isSmallerThanValue(maxRetries) &
                ($nextAttemptAtCol.isNull() |
                    $nextAttemptAtCol.isSmallerOrEqualValue(now)),
          ))
        .get();
  }

  /// Counts all records where syncStatus != synced, regardless of retry count
  /// or backoff. Used to decide whether to show the "Sync now" button.
  Future<int> countUnsynced() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM ${$table.actualTableName} '
      'WHERE ${$syncStatusCol.name} != ?',
      variables: [Variable<int>(SyncStatus.synced.index)],
      readsFrom: {$table},
    ).getSingle();
    return result.read<int>('c');
  }

  /// Writes [serverUpdatedAt] to both [updatedAt] (LWW pivot) and
  /// [lastSyncedAt], and clears retry state.
  ///
  /// WHERE includes [localUpdatedAt] as a race-condition guard: if the user
  /// edited the record while the push was in flight, updatedAt will have
  /// changed and the write becomes a no-op, leaving the record as
  /// pendingUpdate for the next sync cycle.
  Future<void> markAsSynced(
    String id,
    DateTime serverUpdatedAt, {
    required DateTime localUpdatedAt,
  }) {
    return (update($table)
          ..where(
            (_) =>
                $idCol.equals(id) & $updatedAtCol.equals(localUpdatedAt),
          ))
        .write(
          _SyncInsertable({
            $updatedAtCol.name: Variable<DateTime>(serverUpdatedAt),
            $syncStatusCol.name: Variable<int>(SyncStatus.synced.index),
            $retryCountCol.name: Variable<int>(0),
            $lastErrorCol.name: Variable<String>(null),
            $lastSyncedAtCol.name: Variable<DateTime>(serverUpdatedAt),
            $nextAttemptAtCol.name: Variable<DateTime>(null),
          }),
        );
  }

  /// Resets retry state on records blocked past the retry limit. Typically
  /// called on `connectivity_restored` or app resume to give them a new chance.
  Future<int> resetSyncRetries() {
    return (update($table)
          ..where((_) => $retryCountCol.isBiggerThanValue(0)))
        .write(
          _SyncInsertable({
            $retryCountCol.name: Variable<int>(0),
            $lastErrorCol.name: Variable<String>(null),
            $nextAttemptAtCol.name: Variable<DateTime>(null),
          }),
        );
  }

  /// Increments the retry counter, records the error, and schedules the next
  /// attempt with exponential backoff (2, 4, 8, 16 … seconds).
  ///
  /// Uses a raw SELECT to read only [syncRetryCount], avoiding the need to
  /// materialise the full entity data class for a generic D type.
  ///
  /// NB: updatedAt is NOT touched — it is the LWW pivot and must not be
  /// bumped artificially by retry bookkeeping.
  Future<void> incrementSyncRetry(String id, String errorMessage) async {
    final row = await customSelect(
      'SELECT ${$retryCountCol.name} '
      'FROM ${$table.actualTableName} '
      'WHERE ${$idCol.name} = ?',
      variables: [Variable<String>(id)],
      readsFrom: {$table},
    ).getSingleOrNull();
    if (row == null) return;

    final newRetryCount = row.read<int>($retryCountCol.name) + 1;
    final backoffSecs = 2 << (newRetryCount - 1);
    final nextAttempt = DateTime.now().add(Duration(seconds: backoffSecs));

    await (update($table)..where((_) => $idCol.equals(id))).write(
      _SyncInsertable({
        $retryCountCol.name: Variable<int>(newRetryCount),
        $lastErrorCol.name: Variable<String>(errorMessage),
        $nextAttemptAtCol.name: Variable<DateTime>(nextAttempt),
      }),
    );
  }
}
