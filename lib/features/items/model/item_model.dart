// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
        return 'categories.vestiti'.tr();
      case ItemCategory.toiletries:
        return 'categories.toiletries'.tr();
      case ItemCategory.elettronica:
        return 'categories.elettronica'.tr();
      case ItemCategory.varie:
        return 'categories.varie'.tr();
    }
  }

  /// Icona Material associata alla categoria.
  /// Fonte unica di verità: tutti i widget dell'app devono usare questo getter.
  IconData get icon => switch (this) {
    ItemCategory.vestiti => Icons.checkroom,
    ItemCategory.toiletries => Icons.soap,
    ItemCategory.elettronica => Icons.devices,
    ItemCategory.varie => Icons.category,
  };
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

    /// ID dello spazio a cui appartiene l'oggetto (opzionale).
    /// Se null, l'oggetto appartiene al pool generale della casa.
    String? spaceId,

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
