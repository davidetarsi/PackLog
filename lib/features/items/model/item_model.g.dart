// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ItemModelImpl _$$ItemModelImplFromJson(Map<String, dynamic> json) =>
    _$ItemModelImpl(
      id: json['id'] as String,
      houseId: json['houseId'] as String,
      name: json['name'] as String,
      category: $enumDecode(_$ItemCategoryEnumMap, json['category']),
      description: json['description'] as String?,
      quantity: (json['quantity'] as num?)?.toInt(),
      spaceId: json['spaceId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ItemModelImplToJson(_$ItemModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'houseId': instance.houseId,
      'name': instance.name,
      'category': _$ItemCategoryEnumMap[instance.category]!,
      'description': instance.description,
      'quantity': instance.quantity,
      'spaceId': instance.spaceId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$ItemCategoryEnumMap = {
  ItemCategory.vestiti: 'vestiti',
  ItemCategory.toiletries: 'toiletries',
  ItemCategory.elettronica: 'elettronica',
  ItemCategory.varie: 'varie',
};
