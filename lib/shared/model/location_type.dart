import 'package:easy_localization/easy_localization.dart';

/// Tipo di località geografica
enum LocationType {
  /// Città, paese o villaggio
  city('location_types.city'),
  /// Stato, regione o provincia
  state('location_types.state'),
  /// Nazione/Paese
  country('location_types.country'),
  /// Altro tipo non classificato
  other('location_types.other');

  final String _key;
  const LocationType(this._key);
  
  String get displayName => _key.tr();
}
