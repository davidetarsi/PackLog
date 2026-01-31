// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TripItem _$TripItemFromJson(Map<String, dynamic> json) {
  return _TripItem.fromJson(json);
}

/// @nodoc
mixin _$TripItem {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;

  /// ID della casa di origine dell'oggetto (default vuoto per retrocompatibilità)
  String get originHouseId => throw _privateConstructorUsedError;
  bool get isChecked => throw _privateConstructorUsedError;

  /// Serializes this TripItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TripItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TripItemCopyWith<TripItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TripItemCopyWith<$Res> {
  factory $TripItemCopyWith(TripItem value, $Res Function(TripItem) then) =
      _$TripItemCopyWithImpl<$Res, TripItem>;
  @useResult
  $Res call({
    String id,
    String name,
    String category,
    int quantity,
    String originHouseId,
    bool isChecked,
  });
}

/// @nodoc
class _$TripItemCopyWithImpl<$Res, $Val extends TripItem>
    implements $TripItemCopyWith<$Res> {
  _$TripItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TripItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? category = null,
    Object? quantity = null,
    Object? originHouseId = null,
    Object? isChecked = null,
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
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            originHouseId: null == originHouseId
                ? _value.originHouseId
                : originHouseId // ignore: cast_nullable_to_non_nullable
                      as String,
            isChecked: null == isChecked
                ? _value.isChecked
                : isChecked // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TripItemImplCopyWith<$Res>
    implements $TripItemCopyWith<$Res> {
  factory _$$TripItemImplCopyWith(
    _$TripItemImpl value,
    $Res Function(_$TripItemImpl) then,
  ) = __$$TripItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String category,
    int quantity,
    String originHouseId,
    bool isChecked,
  });
}

/// @nodoc
class __$$TripItemImplCopyWithImpl<$Res>
    extends _$TripItemCopyWithImpl<$Res, _$TripItemImpl>
    implements _$$TripItemImplCopyWith<$Res> {
  __$$TripItemImplCopyWithImpl(
    _$TripItemImpl _value,
    $Res Function(_$TripItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TripItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? category = null,
    Object? quantity = null,
    Object? originHouseId = null,
    Object? isChecked = null,
  }) {
    return _then(
      _$TripItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        originHouseId: null == originHouseId
            ? _value.originHouseId
            : originHouseId // ignore: cast_nullable_to_non_nullable
                  as String,
        isChecked: null == isChecked
            ? _value.isChecked
            : isChecked // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TripItemImpl extends _TripItem {
  _$TripItemImpl({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.originHouseId = '',
    this.isChecked = false,
  }) : super._();

  factory _$TripItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$TripItemImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String category;
  @override
  final int quantity;

  /// ID della casa di origine dell'oggetto (default vuoto per retrocompatibilità)
  @override
  @JsonKey()
  final String originHouseId;
  @override
  @JsonKey()
  final bool isChecked;

  @override
  String toString() {
    return 'TripItem(id: $id, name: $name, category: $category, quantity: $quantity, originHouseId: $originHouseId, isChecked: $isChecked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TripItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.originHouseId, originHouseId) ||
                other.originHouseId == originHouseId) &&
            (identical(other.isChecked, isChecked) ||
                other.isChecked == isChecked));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    category,
    quantity,
    originHouseId,
    isChecked,
  );

  /// Create a copy of TripItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TripItemImplCopyWith<_$TripItemImpl> get copyWith =>
      __$$TripItemImplCopyWithImpl<_$TripItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TripItemImplToJson(this);
  }
}

abstract class _TripItem extends TripItem {
  factory _TripItem({
    required final String id,
    required final String name,
    required final String category,
    required final int quantity,
    final String originHouseId,
    final bool isChecked,
  }) = _$TripItemImpl;
  _TripItem._() : super._();

  factory _TripItem.fromJson(Map<String, dynamic> json) =
      _$TripItemImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get category;
  @override
  int get quantity;

  /// ID della casa di origine dell'oggetto (default vuoto per retrocompatibilità)
  @override
  String get originHouseId;
  @override
  bool get isChecked;

  /// Create a copy of TripItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TripItemImplCopyWith<_$TripItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TripModel _$TripModelFromJson(Map<String, dynamic> json) {
  return _TripModel.fromJson(json);
}

/// @nodoc
mixin _$TripModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<TripItem> get items => throw _privateConstructorUsedError;

  /// Data e ora di partenza
  DateTime? get departureDateTime => throw _privateConstructorUsedError;

  /// Data e ora di ritorno
  DateTime? get returnDateTime => throw _privateConstructorUsedError;

  /// Casa di destinazione (opzionale)
  String? get destinationHouseId => throw _privateConstructorUsedError;

  /// Viaggio salvato/preferito
  bool get isSaved => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this TripModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TripModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TripModelCopyWith<TripModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TripModelCopyWith<$Res> {
  factory $TripModelCopyWith(TripModel value, $Res Function(TripModel) then) =
      _$TripModelCopyWithImpl<$Res, TripModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String? description,
    List<TripItem> items,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    String? destinationHouseId,
    bool isSaved,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$TripModelCopyWithImpl<$Res, $Val extends TripModel>
    implements $TripModelCopyWith<$Res> {
  _$TripModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TripModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? items = null,
    Object? departureDateTime = freezed,
    Object? returnDateTime = freezed,
    Object? destinationHouseId = freezed,
    Object? isSaved = null,
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
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<TripItem>,
            departureDateTime: freezed == departureDateTime
                ? _value.departureDateTime
                : departureDateTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            returnDateTime: freezed == returnDateTime
                ? _value.returnDateTime
                : returnDateTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            destinationHouseId: freezed == destinationHouseId
                ? _value.destinationHouseId
                : destinationHouseId // ignore: cast_nullable_to_non_nullable
                      as String?,
            isSaved: null == isSaved
                ? _value.isSaved
                : isSaved // ignore: cast_nullable_to_non_nullable
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
}

/// @nodoc
abstract class _$$TripModelImplCopyWith<$Res>
    implements $TripModelCopyWith<$Res> {
  factory _$$TripModelImplCopyWith(
    _$TripModelImpl value,
    $Res Function(_$TripModelImpl) then,
  ) = __$$TripModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? description,
    List<TripItem> items,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    String? destinationHouseId,
    bool isSaved,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$TripModelImplCopyWithImpl<$Res>
    extends _$TripModelCopyWithImpl<$Res, _$TripModelImpl>
    implements _$$TripModelImplCopyWith<$Res> {
  __$$TripModelImplCopyWithImpl(
    _$TripModelImpl _value,
    $Res Function(_$TripModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TripModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? items = null,
    Object? departureDateTime = freezed,
    Object? returnDateTime = freezed,
    Object? destinationHouseId = freezed,
    Object? isSaved = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$TripModelImpl(
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
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<TripItem>,
        departureDateTime: freezed == departureDateTime
            ? _value.departureDateTime
            : departureDateTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        returnDateTime: freezed == returnDateTime
            ? _value.returnDateTime
            : returnDateTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        destinationHouseId: freezed == destinationHouseId
            ? _value.destinationHouseId
            : destinationHouseId // ignore: cast_nullable_to_non_nullable
                  as String?,
        isSaved: null == isSaved
            ? _value.isSaved
            : isSaved // ignore: cast_nullable_to_non_nullable
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
class _$TripModelImpl extends _TripModel {
  _$TripModelImpl({
    required this.id,
    required this.name,
    this.description,
    final List<TripItem> items = const [],
    this.departureDateTime,
    this.returnDateTime,
    this.destinationHouseId,
    this.isSaved = false,
    required this.createdAt,
    required this.updatedAt,
  }) : _items = items,
       super._();

  factory _$TripModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TripModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  final List<TripItem> _items;
  @override
  @JsonKey()
  List<TripItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Data e ora di partenza
  @override
  final DateTime? departureDateTime;

  /// Data e ora di ritorno
  @override
  final DateTime? returnDateTime;

  /// Casa di destinazione (opzionale)
  @override
  final String? destinationHouseId;

  /// Viaggio salvato/preferito
  @override
  @JsonKey()
  final bool isSaved;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'TripModel(id: $id, name: $name, description: $description, items: $items, departureDateTime: $departureDateTime, returnDateTime: $returnDateTime, destinationHouseId: $destinationHouseId, isSaved: $isSaved, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TripModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.departureDateTime, departureDateTime) ||
                other.departureDateTime == departureDateTime) &&
            (identical(other.returnDateTime, returnDateTime) ||
                other.returnDateTime == returnDateTime) &&
            (identical(other.destinationHouseId, destinationHouseId) ||
                other.destinationHouseId == destinationHouseId) &&
            (identical(other.isSaved, isSaved) || other.isSaved == isSaved) &&
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
    const DeepCollectionEquality().hash(_items),
    departureDateTime,
    returnDateTime,
    destinationHouseId,
    isSaved,
    createdAt,
    updatedAt,
  );

  /// Create a copy of TripModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TripModelImplCopyWith<_$TripModelImpl> get copyWith =>
      __$$TripModelImplCopyWithImpl<_$TripModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TripModelImplToJson(this);
  }
}

abstract class _TripModel extends TripModel {
  factory _TripModel({
    required final String id,
    required final String name,
    final String? description,
    final List<TripItem> items,
    final DateTime? departureDateTime,
    final DateTime? returnDateTime,
    final String? destinationHouseId,
    final bool isSaved,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$TripModelImpl;
  _TripModel._() : super._();

  factory _TripModel.fromJson(Map<String, dynamic> json) =
      _$TripModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  List<TripItem> get items;

  /// Data e ora di partenza
  @override
  DateTime? get departureDateTime;

  /// Data e ora di ritorno
  @override
  DateTime? get returnDateTime;

  /// Casa di destinazione (opzionale)
  @override
  String? get destinationHouseId;

  /// Viaggio salvato/preferito
  @override
  bool get isSaved;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of TripModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TripModelImplCopyWith<_$TripModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
