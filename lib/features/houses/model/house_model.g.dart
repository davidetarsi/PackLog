// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'house_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HouseModelImpl _$$HouseModelImplFromJson(Map<String, dynamic> json) =>
    _$HouseModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      location: json['location'] == null
          ? null
          : LocationSuggestionModel.fromJson(
              json['location'] as Map<String, dynamic>,
            ),
      iconName: json['iconName'] as String? ?? 'home',
      isPrimary: json['isPrimary'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$HouseModelImplToJson(_$HouseModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'location': instance.location,
      'iconName': instance.iconName,
      'isPrimary': instance.isPrimary,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
