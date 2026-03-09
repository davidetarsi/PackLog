import 'package:drift/drift.dart';
import 'houses_table.dart';
import 'spaces_table.dart';

/// Tabella per gli oggetti.
/// 
/// Ogni oggetto appartiene a una casa (foreign key).
/// Opzionalmente, può appartenere a uno spazio specifico della casa.
class Items extends Table {
  /// ID univoco dell'oggetto (UUID)
  TextColumn get id => text()();
  
  /// ID della casa a cui appartiene l'oggetto
  TextColumn get houseId => text().references(Houses, #id)();
  
  /// Nome dell'oggetto
  TextColumn get name => text().withLength(min: 1, max: 200)();
  
  /// Categoria dell'oggetto (vestiti, toiletries, elettronica, varie)
  TextColumn get category => text()();
  
  /// Descrizione opzionale
  TextColumn get description => text().nullable()();
  
  /// Quantità dell'oggetto
  IntColumn get quantity => integer().nullable()();
  
  /// ID dello spazio a cui appartiene l'oggetto (opzionale).
  /// Se null, l'oggetto appartiene al pool generale della casa.
  /// ON DELETE SET NULL: se lo spazio viene eliminato, l'oggetto
  /// torna al pool generale senza essere cancellato.
  TextColumn get spaceId => text().nullable().references(Spaces, #id, onDelete: KeyAction.setNull)();
  
  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();
  
  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
