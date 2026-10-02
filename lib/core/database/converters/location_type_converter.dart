import 'package:drift/drift.dart';
import '../../../shared/model/location_type.dart';

/// Converter Drift nativo per serializzare [LocationType] ↔ [String].
///
/// Applicato alla colonna `location_type` (nullable) nelle tabelle
/// [Houses] e [Trips] tramite `.map(const LocationTypeConverter())`.
/// Drift gestisce automaticamente i valori `null`: il converter viene
/// invocato solo per valori non-null, garantendo il tipo `LocationType?`
/// nel codice Dart generato.
class LocationTypeConverter extends TypeConverter<LocationType, String> {
  const LocationTypeConverter();

  @override
  LocationType fromSql(String fromDb) {
    return LocationType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => LocationType.other,
    );
  }

  @override
  String toSql(LocationType value) => value.name;

  // ── Backward-compat helpers (usati da MigrationService) ──────────────────

  /// Converte [LocationType] in String per il database.
  static String toDatabase(LocationType type) =>
      const LocationTypeConverter().toSql(type);

  /// Converte String? dal database in [LocationType].
  static LocationType fromDatabase(String? value) {
    if (value == null) return LocationType.other;
    return const LocationTypeConverter().fromSql(value);
  }
}
