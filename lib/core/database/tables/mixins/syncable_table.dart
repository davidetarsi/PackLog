import 'package:drift/drift.dart';

/// Sync status for offline-first synchronization with Supabase.
///
/// Stored as integer index via Drift's `intEnum`:
///   synced=0, pendingCreate=1, pendingUpdate=2, pendingDelete=3
///
/// Note su [pendingDelete]: oggi le soft-delete viaggiano come
/// `pendingUpdate` + `is_deleted = true` perché il `SyncService` tratta il
/// caso "remote winner = tombstone" in modo identico a un update. Lo lasciamo
/// nell'enum (e non lo rimuoviamo) per due ragioni:
///   1. Compatibilità DB: righe esistenti potrebbero avere `syncStatus = 3`
///      da versioni precedenti; rimuovere l'enum value romperebbe il
///      `TypeConverter`.
///   2. Evoluzione: distinguere `pendingDelete` può servire in futuro per
///      ottimizzare il payload remoto (es. spedire solo `{id, is_deleted}`
///      senza il resto delle colonne).
enum SyncStatus { synced, pendingCreate, pendingUpdate, pendingDelete }

/// Mixin that adds sync-related columns to entity tables.
///
/// Applied to the 5 main entity tables (Houses, Items, Spaces, Luggages,
/// Trips) to prepare for Supabase offline-first sync. NOT applied to
/// snapshot/junction tables (TripItemEntries, TripLuggageEntries).
mixin SyncableTable on Table {
  /// Supabase user ID. Nullable for backward compatibility: existing
  /// local-only records (pre-sync) will have null until first login.
  TextColumn get userId => text().nullable()();

  /// Current sync state of this record.
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(
    Constant(SyncStatus.pendingCreate.index),
  )();

  /// Number of consecutive failed sync attempts for this record.
  IntColumn get syncRetryCount => integer().withDefault(const Constant(0))();

  /// Last sync error message (null when synced or never attempted).
  TextColumn get lastSyncError => text().nullable()();

  /// Sentry trace ID for correlating sync errors with crash reports.
  TextColumn get sentryTraceId => text().nullable()();

  /// Earliest time the next sync attempt is allowed (exponential backoff).
  /// Null means the record can be synced immediately.
  DateTimeColumn get nextSyncAttemptAt => dateTime().nullable()();
}
