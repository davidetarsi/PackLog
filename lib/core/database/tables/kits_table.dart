import 'package:drift/drift.dart';
import 'houses_table.dart';
import 'mixins/syncable_table.dart';

/// Tabella dei kit: gruppi logici di oggetti della casa che entrano in
/// valigia sciolti (es. "Sci", "Kit aereo").
///
/// Un kit appartiene a una casa. Gli oggetti stanno in [KitItems].
///
/// Indice su [Kits.houseId] — accelera `WHERE house_id = ?` (watchKitsOfHouse).
@TableIndex(name: 'idx_kits_house_id', columns: {#houseId})
class Kits extends Table with SyncableTable {
  /// ID univoco del kit (UUID)
  TextColumn get id => text()();

  /// ID della casa a cui appartiene il kit
  TextColumn get houseId =>
      text().references(Houses, #id, onDelete: KeyAction.cascade)();

  /// Nome del kit (1..60 caratteri)
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Id delle attività del catalogo per cui il kit entra da solo, lista JSON
  /// (`'["ski"]'`). Blob applicativo come `trips.legs`: nessuna query ci filtra.
  TextColumn get activities => text().withDefault(const Constant('[]'))();

  /// Id dei mezzi del catalogo (dominio `transport`), lista JSON.
  TextColumn get transports => text().withDefault(const Constant('[]'))();

  /// Collegamenti imparati dall'uso, JSON:
  /// `{"yes": {"trekking": 2}, "no": ["mare"]}`.
  TextColumn get learned => text().withDefault(const Constant('{}'))();

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
}
