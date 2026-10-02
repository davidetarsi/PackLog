import 'package:drift/drift.dart';
import '../converters/location_type_converter.dart';
import 'mixins/syncable_table.dart';

/// Tabella per le case (luoghi dove sono conservati gli oggetti).
class Houses extends Table with SyncableTable {
  /// ID univoco della casa (UUID)
  TextColumn get id => text()();

  /// Nome della casa
  TextColumn get name => text().withLength(max: 100)();

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

  /// Tipo di località. Drift converte automaticamente la stringa in
  /// [LocationType] tramite [LocationTypeConverter]; null viene passato
  /// attraverso senza conversione (colonna nullable → tipo Dart `LocationType?`).
  TextColumn get locationType =>
      text().nullable().map(const LocationTypeConverter())();

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

  // ── Soft Delete / Sync ──────────────────────────────────────────────────────

  /// Flag di eliminazione logica.
  /// `true` = l'utente ha eliminato la casa; la riga rimane nel DB per la
  /// sincronizzazione cloud e verrà purgata dopo la propagazione al server.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Timestamp dell'ultima sincronizzazione con il cloud.
  /// `null` = mai sincronizzato (record solo locale).
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
