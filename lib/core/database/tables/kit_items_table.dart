import 'package:drift/drift.dart';
import 'items_table.dart';
import 'kits_table.dart';
import 'mixins/syncable_table.dart';

/// Righe di un kit: un oggetto della casa con le copie che il kit porta.
///
/// Una sola riga per coppia (kit, oggetto): se la riga è stata cancellata e
/// l'oggetto rientra nel kit, la si riattiva (vedi `KitsDao.upsertKitItem`).
///
/// La classe dei dati si chiama `KitItemRow` per non scontrarsi con il
/// `KitItem` del modello dell'app.
@DataClassName('KitItemRow')
@TableIndex(name: 'idx_kit_items_kit_id', columns: {#kitId})
@TableIndex(name: 'idx_kit_items_item_id', columns: {#itemId})
class KitItems extends Table with SyncableTable {
  /// ID univoco della riga (UUID)
  TextColumn get id => text()();

  /// Il kit
  TextColumn get kitId =>
      text().references(Kits, #id, onDelete: KeyAction.cascade)();

  /// L'oggetto della casa
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  /// Copie dell'oggetto che il kit porta (>= 1). Il check legge la colonna che
  /// sta definendo: è l'idioma di Drift.
  IntColumn get copies => integer()
      .withDefault(const Constant(1))
      // ignore: recursive_getters
      .check(copies.isBiggerOrEqualValue(1))();

  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();

  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  // ── Soft Delete / Sync ──────────────────────────────────────────────────────

  /// Flag di eliminazione logica.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Timestamp dell'ultima sincronizzazione con il cloud.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {kitId, itemId},
  ];
}
