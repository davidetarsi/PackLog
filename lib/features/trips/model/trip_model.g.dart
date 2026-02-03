// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TripItemImpl _$$TripItemImplFromJson(Map<String, dynamic> json) =>
    _$TripItemImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: (json['quantity'] as num).toInt(),
      originHouseId: json['originHouseId'] as String? ?? '',
      isChecked: json['isChecked'] as bool? ?? false,
    );

Map<String, dynamic> _$$TripItemImplToJson(_$TripItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'quantity': instance.quantity,
      'originHouseId': instance.originHouseId,
      'isChecked': instance.isChecked,
    };

_$TripModelImpl _$$TripModelImplFromJson(Map<String, dynamic> json) =>
    _$TripModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => TripItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      departureDateTime: json['departureDateTime'] == null
          ? null
          : DateTime.parse(json['departureDateTime'] as String),
      returnDateTime: json['returnDateTime'] == null
          ? null
          : DateTime.parse(json['returnDateTime'] as String),
      destinationHouseId: json['destinationHouseId'] as String?,
      destinationLocation: json['destinationLocation'] == null
          ? null
          : LocationSuggestionModel.fromJson(
              json['destinationLocation'] as Map<String, dynamic>,
            ),
      destinationLocationName: json['destinationLocationName'] as String?,
      isSaved: json['isSaved'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$TripModelImplToJson(_$TripModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'items': instance.items,
      'departureDateTime': instance.departureDateTime?.toIso8601String(),
      'returnDateTime': instance.returnDateTime?.toIso8601String(),
      'destinationHouseId': instance.destinationHouseId,
      'destinationLocation': instance.destinationLocation,
      'destinationLocationName': instance.destinationLocationName,
      'isSaved': instance.isSaved,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
