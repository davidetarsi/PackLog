import 'package:drift/drift.dart';
import 'houses_table.dart';
import '../converters/location_type_converter.dart';
import 'mixins/syncable_table.dart';

/// Tabella per i viaggi.
class Trips extends Table with SyncableTable {
  /// ID univoco del viaggio (UUID)
  TextColumn get id => text()();

  /// Nome del viaggio
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Descrizione opzionale
  TextColumn get description => text().nullable()();

  /// Data e ora di partenza
  DateTimeColumn get departureDateTime => dateTime().nullable()();

  /// Data e ora di ritorno
  DateTimeColumn get returnDateTime => dateTime().nullable()();

  /// ID della casa di destinazione (opzionale, foreign key)
  TextColumn get destinationHouseId =>
      text().nullable().references(Houses, #id, onDelete: KeyAction.setNull)();

  // Campi per la località di destinazione (quando non si usa una casa)

  /// ID del luogo da Geoapify
  TextColumn get locationPlaceId => text().nullable()();

  /// Nome visualizzato della località
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
  /// attraverso senza conversione (tipo Dart `LocationType?`).
  TextColumn get locationType =>
      text().nullable().map(const LocationTypeConverter())();

  /// Latitudine
  RealColumn get locationLat => real().nullable()();

  /// Longitudine
  RealColumn get locationLon => real().nullable()();

  /// Viaggio salvato/preferito
  BoolColumn get isSaved => boolean().withDefault(const Constant(false))();

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
