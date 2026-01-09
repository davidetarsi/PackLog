// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ItemModel _$ItemModelFromJson(Map<String, dynamic> json) {
  return _ItemModel.fromJson(json);
}

/// @nodoc
mixin _$ItemModel {
  String get id => throw _privateConstructorUsedError;
  String get houseId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  ItemCategory get category => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  int? get quantity => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ItemModelCopyWith<ItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ItemModelCopyWith<$Res> {
  factory $ItemModelCopyWith(ItemModel value, $Res Function(ItemModel) then) =
      _$ItemModelCopyWithImpl<$Res, ItemModel>;
  @useResult
  $Res call({
    String id,
    String houseId,
    String name,
    ItemCategory category,
    String? description,
    int? quantity,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$ItemModelCopyWithImpl<$Res, $Val extends ItemModel>
    implements $ItemModelCopyWith<$Res> {
  _$ItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? houseId = null,
    Object? name = null,
    Object? category = null,
    Object? description = freezed,
    Object? quantity = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            houseId: null == houseId
                ? _value.houseId
                : houseId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as ItemCategory,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            quantity: freezed == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ItemModelImplCopyWith<$Res>
    implements $ItemModelCopyWith<$Res> {
  factory _$$ItemModelImplCopyWith(
    _$ItemModelImpl value,
    $Res Function(_$ItemModelImpl) then,
  ) = __$$ItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String houseId,
    String name,
    ItemCategory category,
    String? description,
    int? quantity,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$ItemModelImplCopyWithImpl<$Res>
    extends _$ItemModelCopyWithImpl<$Res, _$ItemModelImpl>
    implements _$$ItemModelImplCopyWith<$Res> {
  __$$ItemModelImplCopyWithImpl(
    _$ItemModelImpl _value,
    $Res Function(_$ItemModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? houseId = null,
    Object? name = null,
    Object? category = null,
    Object? description = freezed,
    Object? quantity = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$ItemModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        houseId: null == houseId
            ? _value.houseId
            : houseId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as ItemCategory,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        quantity: freezed == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ItemModelImpl extends _ItemModel {
  _$ItemModelImpl({
    required this.id,
    required this.houseId,
    required this.name,
    required this.category,
    this.description,
    this.quantity,
    required this.createdAt,
    required this.updatedAt,
  }) : super._();

  factory _$ItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ItemModelImplFromJson(json);

  @override
  final String id;
  @override
  final String houseId;
  @override
  final String name;
  @override
  final ItemCategory category;
  @override
  final String? description;
  @override
  final int? quantity;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'ItemModel(id: $id, houseId: $houseId, name: $name, category: $category, description: $description, quantity: $quantity, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.houseId, houseId) || other.houseId == houseId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    houseId,
    name,
    category,
    description,
    quantity,
    createdAt,
    updatedAt,
  );

  /// Create a copy of ItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ItemModelImplCopyWith<_$ItemModelImpl> get copyWith =>
      __$$ItemModelImplCopyWithImpl<_$ItemModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ItemModelImplToJson(this);
  }
}

abstract class _ItemModel extends ItemModel {
  factory _ItemModel({
    required final String id,
    required final String houseId,
    required final String name,
    required final ItemCategory category,
    final String? description,
    final int? quantity,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$ItemModelImpl;
  _ItemModel._() : super._();

  factory _ItemModel.fromJson(Map<String, dynamic> json) =
      _$ItemModelImpl.fromJson;

  @override
  String get id;
  @override
  String get houseId;
  @override
  String get name;
  @override
  ItemCategory get category;
  @override
  String? get description;
  @override
  int? get quantity;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of ItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ItemModelImplCopyWith<_$ItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
