import 'package:drift/drift.dart';
import 'houses_table.dart';
import 'spaces_table.dart';
import '../converters/item_category_converter.dart';
import 'mixins/syncable_table.dart';

/// Indice su [Items.houseId] — accelera le query `WHERE house_id = ?`
/// (getItemsByHouseId, getItemsInGeneralPool, moveItemsToHouse).
@TableIndex(name: 'idx_items_house_id', columns: {#houseId})
/// Indice su [Items.spaceId] — accelera le query `WHERE space_id = ?`
/// (getItemsBySpaceId, countItemsBySpace).
@TableIndex(name: 'idx_items_space_id', columns: {#spaceId})
/// Tabella per gli oggetti.
///
/// Ogni oggetto appartiene a una casa (foreign key).
/// Opzionalmente, può appartenere a uno spazio specifico della casa.
class Items extends Table with SyncableTable {
  /// ID univoco dell'oggetto (UUID)
  TextColumn get id => text()();

  /// ID della casa a cui appartiene l'oggetto
  TextColumn get houseId => text().references(Houses, #id)();

  /// Nome dell'oggetto
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Categoria dell'oggetto. Drift converte automaticamente la stringa
  /// in [ItemCategory] tramite [ItemCategoryConverter].
  TextColumn get category => text().map(const ItemCategoryConverter())();

  /// Descrizione opzionale
  TextColumn get description => text().nullable()();

  /// Quantità dell'oggetto
  IntColumn get quantity => integer().nullable()();

  /// ID dello spazio a cui appartiene l'oggetto (opzionale).
  /// Se null, l'oggetto appartiene al pool generale della casa.
  /// ON DELETE SET NULL: se lo spazio viene eliminato, l'oggetto
  /// torna al pool generale senza essere cancellato.
  TextColumn get spaceId =>
      text().nullable().references(Spaces, #id, onDelete: KeyAction.setNull)();

  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();

  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  // ── Soft Delete / Sync ──────────────────────────────────────────────────────

  /// Flag di eliminazione logica.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  /// Timestamp dell'ultima sincronizzazione con il cloud.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
