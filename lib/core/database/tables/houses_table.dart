import 'package:drift/drift.dart';

/// Tabella per le case (luoghi dove sono conservati gli oggetti).
class Houses extends Table {
  /// ID univoco della casa (UUID)
  TextColumn get id => text()();
  
  /// Nome della casa
  TextColumn get name => text().withLength(min: 1, max: 100)();
  
  /// Descrizione opzionale
  TextColumn get description => text().nullable()();

  // === Campi location (dalla LocationSuggestionModel) ===
  
  /// PlaceId della località (da Geoapify)
  TextColumn get locationPlaceId => text().nullable()();

  /// Nome formattato della località
  TextColumn get locationDisplayName => text().nullable()();

  /// Nome principale della località
  TextColumn get locationName => text().nullable()();

  /// Città
  TextColumn get locationCity => text().nullable()();

  /// Stato/Regione
  TextColumn get locationState => text().nullable()();

  /// Paese
  TextColumn get locationCountry => text().nullable()();

  /// Tipo di località (city, state, country, other)
  TextColumn get locationType => text().nullable()();

  /// Latitudine
  RealColumn get locationLat => real().nullable()();

  /// Longitudine
  RealColumn get locationLon => real().nullable()();

  // === Fine campi location ===

  /// Nome dell'icona Material scelta dall'utente
  TextColumn get iconName => text().withDefault(const Constant('home'))();

  /// Se questa è la casa principale
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  
  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();
  
  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
