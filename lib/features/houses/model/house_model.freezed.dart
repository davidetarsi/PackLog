// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'house_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

HouseModel _$HouseModelFromJson(Map<String, dynamic> json) {
  return _HouseModel.fromJson(json);
}

/// @nodoc
mixin _$HouseModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Località della casa (da LocationAutocompleteField)
  LocationSuggestionModel? get location => throw _privateConstructorUsedError;

  /// Nome dell'icona Material scelta dall'utente (es. 'home', 'apartment', 'cottage')
  String get iconName => throw _privateConstructorUsedError;

  /// Se questa è la casa principale dell'utente
  bool get isPrimary => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this HouseModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HouseModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HouseModelCopyWith<HouseModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HouseModelCopyWith<$Res> {
  factory $HouseModelCopyWith(
    HouseModel value,
    $Res Function(HouseModel) then,
  ) = _$HouseModelCopyWithImpl<$Res, HouseModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String? description,
    LocationSuggestionModel? location,
    String iconName,
    bool isPrimary,
    DateTime createdAt,
    DateTime updatedAt,
  });

  $LocationSuggestionModelCopyWith<$Res>? get location;
}

/// @nodoc
class _$HouseModelCopyWithImpl<$Res, $Val extends HouseModel>
    implements $HouseModelCopyWith<$Res> {
  _$HouseModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HouseModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? location = freezed,
    Object? iconName = null,
    Object? isPrimary = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            location: freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as LocationSuggestionModel?,
            iconName: null == iconName
                ? _value.iconName
                : iconName // ignore: cast_nullable_to_non_nullable
                      as String,
            isPrimary: null == isPrimary
                ? _value.isPrimary
                : isPrimary // ignore: cast_nullable_to_non_nullable
                      as bool,
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

  /// Create a copy of HouseModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationSuggestionModelCopyWith<$Res>? get location {
    if (_value.location == null) {
      return null;
    }

    return $LocationSuggestionModelCopyWith<$Res>(_value.location!, (value) {
      return _then(_value.copyWith(location: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HouseModelImplCopyWith<$Res>
    implements $HouseModelCopyWith<$Res> {
  factory _$$HouseModelImplCopyWith(
    _$HouseModelImpl value,
    $Res Function(_$HouseModelImpl) then,
  ) = __$$HouseModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? description,
    LocationSuggestionModel? location,
    String iconName,
    bool isPrimary,
    DateTime createdAt,
    DateTime updatedAt,
  });

  @override
  $LocationSuggestionModelCopyWith<$Res>? get location;
}

/// @nodoc
class __$$HouseModelImplCopyWithImpl<$Res>
    extends _$HouseModelCopyWithImpl<$Res, _$HouseModelImpl>
    implements _$$HouseModelImplCopyWith<$Res> {
  __$$HouseModelImplCopyWithImpl(
    _$HouseModelImpl _value,
    $Res Function(_$HouseModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HouseModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? location = freezed,
    Object? iconName = null,
    Object? isPrimary = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$HouseModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        location: freezed == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as LocationSuggestionModel?,
        iconName: null == iconName
            ? _value.iconName
            : iconName // ignore: cast_nullable_to_non_nullable
                  as String,
        isPrimary: null == isPrimary
            ? _value.isPrimary
            : isPrimary // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$HouseModelImpl extends _HouseModel {
  _$HouseModelImpl({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.iconName = 'home',
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  }) : super._();

  factory _$HouseModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$HouseModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;

  /// Località della casa (da LocationAutocompleteField)
  @override
  final LocationSuggestionModel? location;

  /// Nome dell'icona Material scelta dall'utente (es. 'home', 'apartment', 'cottage')
  @override
  @JsonKey()
  final String iconName;

  /// Se questa è la casa principale dell'utente
  @override
  @JsonKey()
  final bool isPrimary;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'HouseModel(id: $id, name: $name, description: $description, location: $location, iconName: $iconName, isPrimary: $isPrimary, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HouseModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            (identical(other.isPrimary, isPrimary) ||
                other.isPrimary == isPrimary) &&
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
    name,
    description,
    location,
    iconName,
    isPrimary,
    createdAt,
    updatedAt,
  );

  /// Create a copy of HouseModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HouseModelImplCopyWith<_$HouseModelImpl> get copyWith =>
      __$$HouseModelImplCopyWithImpl<_$HouseModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HouseModelImplToJson(this);
  }
}

abstract class _HouseModel extends HouseModel {
  factory _HouseModel({
    required final String id,
    required final String name,
    final String? description,
    final LocationSuggestionModel? location,
    final String iconName,
    final bool isPrimary,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$HouseModelImpl;
  _HouseModel._() : super._();

  factory _HouseModel.fromJson(Map<String, dynamic> json) =
      _$HouseModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;

  /// Località della casa (da LocationAutocompleteField)
  @override
  LocationSuggestionModel? get location;

  /// Nome dell'icona Material scelta dall'utente (es. 'home', 'apartment', 'cottage')
  @override
  String get iconName;

  /// Se questa è la casa principale dell'utente
  @override
  bool get isPrimary;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of HouseModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HouseModelImplCopyWith<_$HouseModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
