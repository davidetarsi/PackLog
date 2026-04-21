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
///
/// Indice su [TripLuggageEntries.luggageId] — la PK è `{tripId, luggageId}`,
/// quindi `tripId` è già coperto dall'indice PK. L'indice su `luggageId`
/// è necessario per ottimizzare il cascade delete da Luggages e le query
/// di JOIN filtrate per `luggage_id`.
@TableIndex(name: 'idx_trip_luggage_entries_luggage_id', columns: {#luggageId})
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
