// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_model.freezed.dart';
part 'item_model.g.dart';

enum ItemCategory {
  @JsonValue('vestiti')
  vestiti,
  @JsonValue('toiletries')
  toiletries,
  @JsonValue('elettronica')
  elettronica,
  @JsonValue('varie')
  varie,
}

extension ItemCategoryExtension on ItemCategory {
  String get displayName {
    switch (this) {
      case ItemCategory.vestiti:
        return 'Vestiti';
      case ItemCategory.toiletries:
        return 'Toiletries';
      case ItemCategory.elettronica:
        return 'Elettronica';
      case ItemCategory.varie:
        return 'Varie';
    }
  }
}

@freezed
class ItemModel with _$ItemModel {
  const ItemModel._();

  factory ItemModel({
    required String id,
    required String houseId,
    required String name,
    required ItemCategory category,
    String? description,
    int? quantity,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ItemModel;

  factory ItemModel.empty(String houseId) {
    return ItemModel(
      id: '',
      houseId: houseId,
      name: '',
      category: ItemCategory.varie,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) =>
      _$ItemModelFromJson(json);
}
