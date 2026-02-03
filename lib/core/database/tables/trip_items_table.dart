import 'package:drift/drift.dart';
import 'trips_table.dart';

/// Tabella per gli oggetti associati a un viaggio.
/// 
/// Questi sono copie degli oggetti originali, non riferimenti.
/// Quando un oggetto viene aggiunto a un viaggio, i suoi dati
/// vengono copiati qui, così le modifiche all'oggetto originale
/// non influenzano il viaggio.
/// 
/// Nota: Usa il nome "TripItemEntries" per evitare conflitti con
/// TripItem del modello dell'app.
@DataClassName('TripItemEntry')
class TripItemEntries extends Table {
  /// ID univoco dell'oggetto nel viaggio (UUID)
  TextColumn get id => text()();
  
  /// ID del viaggio a cui appartiene
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  
  /// Nome dell'oggetto (copia)
  TextColumn get name => text()();
  
  /// Categoria dell'oggetto (copia)
  TextColumn get category => text()();
  
  /// Quantità da portare nel viaggio
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  
  /// ID della casa di origine dell'oggetto
  TextColumn get originHouseId => text().withDefault(const Constant(''))();
  
  /// Se l'oggetto è stato spuntato/preparato
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  /// Chiave primaria composta: lo stesso oggetto (id) può esistere
  /// in viaggi diversi (tripId), ma non può essere duplicato
  /// nello stesso viaggio.
  @override
  Set<Column> get primaryKey => {id, tripId};
}
