import 'package:drift/drift.dart';
import 'houses_table.dart';

/// Tabella per gli spazi/armadi all'interno delle case.
/// 
/// Gli spazi permettono di organizzare gli oggetti in modo più granulare
/// all'interno di una casa (es. "Armadio Camera", "Ripostiglio").
/// 
/// **Struttura Flat**: Non supportiamo spazi nested per evitare
/// complessità di Recursive CTE in SQLite.
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

  @override
  Set<Column> get primaryKey => {id};
}
