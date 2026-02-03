import 'package:drift/drift.dart';

/// Tabella per le case (luoghi dove sono conservati gli oggetti).
class Houses extends Table {
  /// ID univoco della casa (UUID)
  TextColumn get id => text()();
  
  /// Nome della casa
  TextColumn get name => text().withLength(min: 1, max: 100)();
  
  /// Descrizione opzionale
  TextColumn get description => text().nullable()();
  
  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();
  
  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
