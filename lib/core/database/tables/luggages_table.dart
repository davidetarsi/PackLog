import 'package:drift/drift.dart';
import 'houses_table.dart';
import '../converters/luggage_size_converter.dart';

/// Tabella per i bagagli riutilizzabili.
/// 
/// I bagagli sono entità globali che appartengono a una casa specifica
/// e possono essere linkati a viaggi multipli tramite la junction table
/// `trip_luggage_entries`.
///
/// Indice su [Luggages.houseId] — accelera le query `WHERE house_id = ?`
/// (getLuggagesByHouse, watchLuggagesByHouse, countLuggagesByHouse).
@TableIndex(name: 'idx_luggages_house_id', columns: {#houseId})
class Luggages extends Table {
  /// ID univoco del bagaglio (UUID)
  TextColumn get id => text()();
  
  /// ID della casa a cui appartiene il bagaglio
  TextColumn get houseId => text().references(Houses, #id, onDelete: KeyAction.cascade)();
  
  /// Nome del bagaglio (es. "Zaino Blu", "Valigia Grande")
  TextColumn get name => text().withLength(min: 1, max: 100)();
  
  /// Taglia standard: small_backpack, cabin_baggage, hold_baggage, custom
  /// Dimensione del bagaglio. Drift converte automaticamente la stringa
  /// in [LuggageSize] tramite [LuggageSizeConverter].
  TextColumn get sizeType =>
      text().map(const LuggageSizeConverter())();
  
  /// Volume in litri (opzionale, obbligatorio solo se sizeType == 'custom')
  IntColumn get volumeLiters => integer().nullable()();
  
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
