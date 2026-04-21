import 'package:drift/drift.dart';
import 'houses_table.dart';

/// Tabella per gli spazi/armadi all'interno delle case.
/// 
/// Gli spazi permettono di organizzare gli oggetti in modo più granulare
/// all'interno di una casa (es. "Armadio Camera", "Ripostiglio").
/// 
/// **Struttura Flat**: Non supportiamo spazi nested per evitare
/// complessità di Recursive CTE in SQLite.
///
/// Indice su [Spaces.houseId] — accelera le query `WHERE house_id = ?`
/// (getSpacesByHouse, watchSpacesByHouse, countSpacesByHouse).
@TableIndex(name: 'idx_spaces_house_id', columns: {#houseId})
class Spaces extends Table {
  /// ID univoco dello spazio (UUID)
  TextColumn get id => text()();
  
  /// ID della casa a cui appartiene lo spazio
  TextColumn get houseId => text().references(Houses, #id, onDelete: KeyAction.cascade)();
  
  /// Nome dello spazio
  TextColumn get name => text().withLength(min: 1, max: 100)();
  
  /// Nome dell'icona Material opzionale (es. 'closet', 'garage', 'storage')
  TextColumn get iconName => text().nullable()();
  
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
