// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';
import 'geoapify_response_model.dart';
import 'location_type.dart';

part 'location_suggestion_model.freezed.dart';
part 'location_suggestion_model.g.dart';

/// Modello per rappresentare una località da mostrare all'utente.
///
/// Utilizzato dal widget [LocationAutocompleteField] per mostrare
/// suggerimenti di città, regioni e paesi.
///
/// Può essere creato da:
/// - [LocationSuggestionModel.fromGeoapifyFeature] - da un feature Geoapify
/// - [LocationSuggestionModel.fromGeoapifyProperties] - dalle properties Geoapify
/// - [LocationSuggestionModel.fromJson] - da JSON generico
@freezed
class LocationSuggestionModel with _$LocationSuggestionModel {
  const LocationSuggestionModel._();

  factory LocationSuggestionModel({
    /// ID univoco del luogo (da Geoapify)
    required String placeId,

    /// Nome completo formattato per la visualizzazione
    required String displayName,

    /// Nome principale (città, regione o stato)
    String? name,

    /// Nome della città (se applicabile)
    String? city,

    /// Nome dello stato/regione (se applicabile)
    String? state,

    /// Nome del paese
    String? country,

    /// Tipo di località
    @Default(LocationType.other) LocationType locationType,

    /// Latitudine
    double? lat,

    /// Longitudine
    double? lon,
  }) = _LocationSuggestionModel;

  /// Crea un [LocationSuggestionModel] da un [GeoapifyFeatureModel].
  ///
  /// Questo è il metodo preferito quando si ha l'intero feature.
  factory LocationSuggestionModel.fromGeoapifyFeature(
    GeoapifyFeatureModel feature,
  ) {
    final properties = feature.properties;
    if (properties == null) {
      return LocationSuggestionModel(placeId: '', displayName: '');
    }
    return LocationSuggestionModel.fromGeoapifyProperties(properties);
  }

  /// Crea un [LocationSuggestionModel] da [GeoapifyPropertiesModel].
  ///
  /// Estrae e trasforma i dati delle properties nel formato
  /// utilizzato dall'applicazione.
  factory LocationSuggestionModel.fromGeoapifyProperties(
    GeoapifyPropertiesModel properties,
  ) {
    // Determina il tipo di località e il nome principale
    final (locationType, mainName) = _parseLocationType(properties);

    // Costruisci il displayName
    final displayName = _buildDisplayName(
      locationType: locationType,
      mainName: mainName,
      country: properties.country,
      formatted: properties.formatted ?? '',
    );

    return LocationSuggestionModel(
      placeId: properties.placeId ?? '',
      displayName: displayName,
      name: mainName,
      city: properties.city,
      state: properties.state,
      country: properties.country,
      locationType: locationType,
      lat: properties.lat,
      lon: properties.lon,
    );
  }

  /// Chiave univoca per la deduplicazione (nome + tipo + paese)
  String get deduplicationKey {
    final normalizedName = (name ?? displayName).toLowerCase().trim();
    return '$normalizedName|${locationType.name}|${country?.toLowerCase() ?? ''}';
  }

  factory LocationSuggestionModel.fromJson(Map<String, dynamic> json) =>
      _$LocationSuggestionModelFromJson(json);
}

/// Determina il tipo di località e il nome principale basandosi sulle properties.
(LocationType, String?) _parseLocationType(GeoapifyPropertiesModel p) {
  final resultType = p.resultType ?? '';

  switch (resultType) {
    case 'country':
      // Per i paesi, usa il campo 'country' che è nella lingua richiesta
      return (LocationType.country, p.country ?? p.name);

    case 'state':
    case 'region':
    case 'county':
    case 'province':
      return (LocationType.state, p.state ?? p.county ?? p.name);

    case 'city':
    case 'town':
    case 'village':
    case 'municipality':
      return (LocationType.city, p.city ?? p.name);

    case 'postcode':
    case 'suburb':
    case 'district':
    case 'locality':
    case 'neighbourhood':
      // Sottotipi: determina in base ai campi disponibili
      if (p.city != null) {
        return (LocationType.city, p.city);
      } else if (p.state != null || p.county != null) {
        return (LocationType.state, p.state ?? p.county);
      } else {
        return (LocationType.other, p.name ?? p.country);
      }

    default:
      // Fallback: deduce dal contesto
      if (p.city == null &&
          p.state == null &&
          p.county == null &&
          p.country != null &&
          p.name == p.country) {
        return (LocationType.country, p.country);
      } else if (p.city == null && (p.state != null || p.county != null)) {
        return (LocationType.state, p.state ?? p.county ?? p.name);
      } else if (p.city != null) {
        return (LocationType.city, p.city);
      } else {
        return (
          LocationType.other,
          p.name ?? p.city ?? p.state ?? p.county ?? p.country,
        );
      }
  }
}

/// Costruisce il nome visualizzato in italiano.
String _buildDisplayName({
  required LocationType locationType,
  String? mainName,
  String? country,
  required String formatted,
}) {
  final parts = <String>[];

  if (mainName != null) {
    parts.add(mainName);
  }

  // Aggiungi contesto in base al tipo
  switch (locationType) {
    case LocationType.city:
      if (country != null) {
        parts.add(country);
      }
      break;
    case LocationType.state:
      if (country != null && country != mainName) {
        parts.add(country);
      }
      break;
    case LocationType.country:
    case LocationType.other:
      // Per i paesi e altri, non aggiungere nulla
      break;
  }

  final displayName = parts.isNotEmpty ? parts.join(', ') : formatted;
  return displayName.isNotEmpty ? displayName : formatted;
}
