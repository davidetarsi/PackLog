// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../shared/model/location_suggestion_model.dart';

part 'house_model.freezed.dart';
part 'house_model.g.dart';

/// Risolve il nome "effettivo" di una casa con un'unica priorità condivisa
/// tra UI ([HouseModel.displayName]) e sync verso Supabase
/// ([SyncSerializers.houseToJson]): nome (trimmed) → città → nome completo
/// della località → [fallback] fornito dal chiamante.
///
/// Il [fallback] è un parametro esplicito (non hardcoded qui) perché i due
/// chiamanti hanno esigenze diverse: la UI vuole una stringa localizzata
/// (`'houses.unnamed_house'.tr()`), il sync no — il vincolo
/// `houses_name_check` su Supabase richiede solo `char_length(name) >= 1`,
/// non un valore user-facing, e chiamare `.tr()` da un path di sync in
/// background è fragile (locale non ancora inizializzato all'avvio).
String resolveHouseDisplayName({
  required String name,
  String? cityName,
  String? locationDisplayName,
  required String fallback,
}) {
  final trimmedName = name.trim();
  if (trimmedName.isNotEmpty) return trimmedName;
  final locationFallback = cityName ?? locationDisplayName ?? '';
  return locationFallback.isNotEmpty ? locationFallback : fallback;
}

@freezed
class HouseModel with _$HouseModel {
  const HouseModel._();

  factory HouseModel({
    required String id,
    required String name,
    String? description,

    /// Località della casa (da LocationAutocompleteField)
    LocationSuggestionModel? location,

    /// Nome dell'icona Material scelta dall'utente (es. 'home', 'apartment', 'cottage')
    @Default('home') String iconName,

    /// Se questa è la casa principale dell'utente
    @Default(false) bool isPrimary,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _HouseModel;

  factory HouseModel.empty() {
    return HouseModel(
      id: '',
      name: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Restituisce il nome della località per la visualizzazione
  String? get locationDisplayName => location?.displayName;

  /// Restituisce la città della località
  String? get cityName => location?.city;

  /// Restituisce il nome da mostrare in UI.
  /// Priorità: name (trimmed) → cityName → locationDisplayName → fallback l10n.
  String get displayName => resolveHouseDisplayName(
    name: name,
    cityName: cityName,
    locationDisplayName: locationDisplayName,
    fallback: 'houses.unnamed_house'.tr(),
  );

  factory HouseModel.fromJson(Map<String, dynamic> json) =>
      _$HouseModelFromJson(json);
}
