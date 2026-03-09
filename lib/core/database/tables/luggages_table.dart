import 'package:drift/drift.dart';
import 'houses_table.dart';

/// Tabella per i bagagli riutilizzabili.
/// 
/// I bagagli sono entità globali che appartengono a una casa specifica
/// e possono essere linkati a viaggi multipli tramite la junction table
/// `trip_luggage_entries`.
class Luggages extends Table {
  /// ID univoco del bagaglio (UUID)
  TextColumn get id => text()();
  
  /// ID della casa a cui appartiene il bagaglio
  TextColumn get houseId => text().references(Houses, #id, onDelete: KeyAction.cascade)();
  
  /// Nome del bagaglio (es. "Zaino Blu", "Valigia Grande")
  TextColumn get name => text().withLength(min: 1, max: 100)();
  
  /// Taglia standard: small_backpack, cabin_baggage, hold_baggage, custom
  TextColumn get sizeType => text()();
  
  /// Volume in litri (opzionale, obbligatorio solo se sizeType == 'custom')
  IntColumn get volumeLiters => integer().nullable()();
  
  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();
  
  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
