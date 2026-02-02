// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';

part 'geoapify_response_model.freezed.dart';
part 'geoapify_response_model.g.dart';

/// Modello per la risposta completa dell'API Geoapify Autocomplete.
///
/// Rappresenta la struttura GeoJSON restituita dall'endpoint:
/// `https://api.geoapify.com/v1/geocode/autocomplete`
@freezed
class GeoapifyResponseModel with _$GeoapifyResponseModel {
  const GeoapifyResponseModel._();

  factory GeoapifyResponseModel({
    /// Tipo di collezione GeoJSON (sempre "FeatureCollection")
    String? type,

    /// Lista dei risultati (features)
    @Default([]) List<GeoapifyFeatureModel> features,
  }) = _GeoapifyResponseModel;

  factory GeoapifyResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GeoapifyResponseModelFromJson(json);
}

/// Modello per un singolo feature/risultato di Geoapify.
///
/// Ogni feature rappresenta una località trovata.
@freezed
class GeoapifyFeatureModel with _$GeoapifyFeatureModel {
  const GeoapifyFeatureModel._();

  factory GeoapifyFeatureModel({
    /// Tipo di feature GeoJSON (sempre "Feature")
    String? type,

    /// Proprietà della località
    GeoapifyPropertiesModel? properties,
  }) = _GeoapifyFeatureModel;

  factory GeoapifyFeatureModel.fromJson(Map<String, dynamic> json) =>
      _$GeoapifyFeatureModelFromJson(json);
}

/// Modello per le proprietà di una località Geoapify.
///
/// Contiene tutti i dati della località come nome, coordinate,
/// indirizzo formattato, tipo di risultato, ecc.
@freezed
class GeoapifyPropertiesModel with _$GeoapifyPropertiesModel {
  const GeoapifyPropertiesModel._();

  factory GeoapifyPropertiesModel({
    /// ID univoco del luogo
    String? placeId,

    /// Tipo di risultato (city, country, state, postcode, ecc.)
    String? resultType,

    /// Nome del luogo
    String? name,

    /// Nome della città
    String? city,

    /// Nome dello stato/regione
    String? state,

    /// Nome della contea/provincia
    String? county,

    /// Nome del paese
    String? country,

    /// Codice del paese (es. "it", "us")
    String? countryCode,

    /// Indirizzo formattato completo
    String? formatted,

    /// Prima riga dell'indirizzo
    String? addressLine1,

    /// Seconda riga dell'indirizzo
    String? addressLine2,

    /// Latitudine
    double? lat,

    /// Longitudine
    double? lon,

    /// CAP/Codice postale
    String? postcode,

    /// Quartiere/Sobborgo
    String? suburb,

    /// Distretto
    String? district,

    /// Frazione
    String? hamlet,

    /// Villaggio
    String? village,

    /// Municipalità
    String? municipality,

    /// Categoria del risultato
    String? category,
  }) = _GeoapifyPropertiesModel;

  factory GeoapifyPropertiesModel.fromJson(Map<String, dynamic> json) =>
      _$GeoapifyPropertiesModelFromJson(json);
}
