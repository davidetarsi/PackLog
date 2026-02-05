// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../shared/model/location_suggestion_model.dart';

part 'house_model.freezed.dart';
part 'house_model.g.dart';

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

  factory HouseModel.fromJson(Map<String, dynamic> json) =>
      _$HouseModelFromJson(json);
}
