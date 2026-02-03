import '../../../shared/model/location_type.dart';

/// Funzioni helper per convertire LocationType da/verso String.
/// 
/// Drift salva i tipi di località come stringhe nel database.
class LocationTypeConverter {
  /// Converte LocationType in String per il database
  static String toDatabase(LocationType type) {
    return type.name;
  }

  /// Converte String dal database in LocationType
  static LocationType fromDatabase(String? value) {
    if (value == null) return LocationType.other;
    return LocationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LocationType.other,
    );
  }
}
