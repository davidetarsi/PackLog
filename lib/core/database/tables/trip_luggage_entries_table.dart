import 'package:drift/drift.dart';
import 'trips_table.dart';
import 'luggages_table.dart';

/// Tabella di junction per la relazione M:N tra Trips e Luggages.
/// 
/// **Pattern**: Relazione diretta (non snapshot), i bagagli sono
/// entità riutilizzabili che vengono linkate ai viaggi.
/// 
/// **Cascade Delete**: Eliminando un Trip o un Luggage, le entry
/// corrispondenti vengono eliminate automaticamente.
@DataClassName('TripLuggageEntry')
class TripLuggageEntries extends Table {
  /// ID del viaggio
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  
  /// ID del bagaglio
  TextColumn get luggageId => text().references(Luggages, #id, onDelete: KeyAction.cascade)();

  /// Chiave primaria composta: un bagaglio può essere associato
  /// a un solo viaggio una volta sola, ma lo stesso bagaglio può
  /// essere riutilizzato in viaggi diversi.
  @override
  Set<Column> get primaryKey => {tripId, luggageId};
}
