// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';

part 'space_model.freezed.dart';
part 'space_model.g.dart';

/// Rappresenta uno spazio/armadio all'interno di una casa.
/// 
/// Gli spazi permettono di organizzare gli oggetti in modo più granulare
/// all'interno di una casa (es. "Armadio Camera", "Ripostiglio", "Garage").
@freezed
class SpaceModel with _$SpaceModel {
  const SpaceModel._();

  factory SpaceModel({
    required String id,
    
    /// ID della casa a cui appartiene lo spazio
    required String houseId,
    
    /// Nome dello spazio (es. "Armadio Camera", "Garage")
    required String name,
    
    /// Nome dell'icona Material opzionale (es. 'closet', 'garage', 'storage')
    String? iconName,
    
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SpaceModel;

  factory SpaceModel.empty(String houseId) {
    return SpaceModel(
      id: '',
      houseId: houseId,
      name: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory SpaceModel.fromJson(Map<String, dynamic> json) =>
      _$SpaceModelFromJson(json);
}
