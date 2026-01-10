// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_items_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$itemTripStatusHash() => r'b01f1777b37b919c1d50091745a4def6c13ee200';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
///
/// Copied from [itemTripStatus].
@ProviderFor(itemTripStatus)
const itemTripStatusProvider = ItemTripStatusFamily();

/// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
///
/// Copied from [itemTripStatus].
class ItemTripStatusFamily extends Family<ItemTripStatus> {
  /// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
  ///
  /// Copied from [itemTripStatus].
  const ItemTripStatusFamily();

  /// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
  ///
  /// Copied from [itemTripStatus].
  ItemTripStatusProvider call(String itemId) {
    return ItemTripStatusProvider(itemId);
  }

  @override
  ItemTripStatusProvider getProviderOverride(
    covariant ItemTripStatusProvider provider,
  ) {
    return call(provider.itemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'itemTripStatusProvider';
}

/// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
///
/// Copied from [itemTripStatus].
class ItemTripStatusProvider extends AutoDisposeProvider<ItemTripStatus> {
  /// Provider che fornisce lo stato di un item specifico rispetto ai viaggi
  ///
  /// Copied from [itemTripStatus].
  ItemTripStatusProvider(String itemId)
    : this._internal(
        (ref) => itemTripStatus(ref as ItemTripStatusRef, itemId),
        from: itemTripStatusProvider,
        name: r'itemTripStatusProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$itemTripStatusHash,
        dependencies: ItemTripStatusFamily._dependencies,
        allTransitiveDependencies:
            ItemTripStatusFamily._allTransitiveDependencies,
        itemId: itemId,
      );

  ItemTripStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.itemId,
  }) : super.internal();

  final String itemId;

  @override
  Override overrideWith(
    ItemTripStatus Function(ItemTripStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ItemTripStatusProvider._internal(
        (ref) => create(ref as ItemTripStatusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        itemId: itemId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<ItemTripStatus> createElement() {
    return _ItemTripStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemTripStatusProvider && other.itemId == itemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, itemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ItemTripStatusRef on AutoDisposeProviderRef<ItemTripStatus> {
  /// The parameter `itemId` of this provider.
  String get itemId;
}

class _ItemTripStatusProviderElement
    extends AutoDisposeProviderElement<ItemTripStatus>
    with ItemTripStatusRef {
  _ItemTripStatusProviderElement(super.provider);

  @override
  String get itemId => (origin as ItemTripStatusProvider).itemId;
}

String _$itemsOnTripFromHouseHash() =>
    r'a966d370037612460cb8fe7b38507a6f7089b010';

/// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
///
/// Copied from [itemsOnTripFromHouse].
@ProviderFor(itemsOnTripFromHouse)
const itemsOnTripFromHouseProvider = ItemsOnTripFromHouseFamily();

/// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
///
/// Copied from [itemsOnTripFromHouse].
class ItemsOnTripFromHouseFamily extends Family<Set<String>> {
  /// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
  ///
  /// Copied from [itemsOnTripFromHouse].
  const ItemsOnTripFromHouseFamily();

  /// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
  ///
  /// Copied from [itemsOnTripFromHouse].
  ItemsOnTripFromHouseProvider call(String houseId) {
    return ItemsOnTripFromHouseProvider(houseId);
  }

  @override
  ItemsOnTripFromHouseProvider getProviderOverride(
    covariant ItemsOnTripFromHouseProvider provider,
  ) {
    return call(provider.houseId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'itemsOnTripFromHouseProvider';
}

/// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
///
/// Copied from [itemsOnTripFromHouse].
class ItemsOnTripFromHouseProvider extends AutoDisposeProvider<Set<String>> {
  /// Provider che fornisce la lista degli item IDs attualmente in viaggio per una casa specifica
  ///
  /// Copied from [itemsOnTripFromHouse].
  ItemsOnTripFromHouseProvider(String houseId)
    : this._internal(
        (ref) => itemsOnTripFromHouse(ref as ItemsOnTripFromHouseRef, houseId),
        from: itemsOnTripFromHouseProvider,
        name: r'itemsOnTripFromHouseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$itemsOnTripFromHouseHash,
        dependencies: ItemsOnTripFromHouseFamily._dependencies,
        allTransitiveDependencies:
            ItemsOnTripFromHouseFamily._allTransitiveDependencies,
        houseId: houseId,
      );

  ItemsOnTripFromHouseProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.houseId,
  }) : super.internal();

  final String houseId;

  @override
  Override overrideWith(
    Set<String> Function(ItemsOnTripFromHouseRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ItemsOnTripFromHouseProvider._internal(
        (ref) => create(ref as ItemsOnTripFromHouseRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        houseId: houseId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Set<String>> createElement() {
    return _ItemsOnTripFromHouseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemsOnTripFromHouseProvider && other.houseId == houseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, houseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ItemsOnTripFromHouseRef on AutoDisposeProviderRef<Set<String>> {
  /// The parameter `houseId` of this provider.
  String get houseId;
}

class _ItemsOnTripFromHouseProviderElement
    extends AutoDisposeProviderElement<Set<String>>
    with ItemsOnTripFromHouseRef {
  _ItemsOnTripFromHouseProviderElement(super.provider);

  @override
  String get houseId => (origin as ItemsOnTripFromHouseProvider).houseId;
}

String _$itemQuantitiesOnTripFromHouseHash() =>
    r'9097bc937d4eaae82970d10fa7bd326b6b580f70';

/// Provider che fornisce le quantità in viaggio per ogni item di una casa
/// Restituisce una mappa {itemId: quantitàInViaggio}
///
/// Copied from [itemQuantitiesOnTripFromHouse].
@ProviderFor(itemQuantitiesOnTripFromHouse)
const itemQuantitiesOnTripFromHouseProvider =
    ItemQuantitiesOnTripFromHouseFamily();

/// Provider che fornisce le quantità in viaggio per ogni item di una casa
/// Restituisce una mappa {itemId: quantitàInViaggio}
///
/// Copied from [itemQuantitiesOnTripFromHouse].
class ItemQuantitiesOnTripFromHouseFamily extends Family<Map<String, int>> {
  /// Provider che fornisce le quantità in viaggio per ogni item di una casa
  /// Restituisce una mappa {itemId: quantitàInViaggio}
  ///
  /// Copied from [itemQuantitiesOnTripFromHouse].
  const ItemQuantitiesOnTripFromHouseFamily();

  /// Provider che fornisce le quantità in viaggio per ogni item di una casa
  /// Restituisce una mappa {itemId: quantitàInViaggio}
  ///
  /// Copied from [itemQuantitiesOnTripFromHouse].
  ItemQuantitiesOnTripFromHouseProvider call(String houseId) {
    return ItemQuantitiesOnTripFromHouseProvider(houseId);
  }

  @override
  ItemQuantitiesOnTripFromHouseProvider getProviderOverride(
    covariant ItemQuantitiesOnTripFromHouseProvider provider,
  ) {
    return call(provider.houseId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'itemQuantitiesOnTripFromHouseProvider';
}

/// Provider che fornisce le quantità in viaggio per ogni item di una casa
/// Restituisce una mappa {itemId: quantitàInViaggio}
///
/// Copied from [itemQuantitiesOnTripFromHouse].
class ItemQuantitiesOnTripFromHouseProvider
    extends AutoDisposeProvider<Map<String, int>> {
  /// Provider che fornisce le quantità in viaggio per ogni item di una casa
  /// Restituisce una mappa {itemId: quantitàInViaggio}
  ///
  /// Copied from [itemQuantitiesOnTripFromHouse].
  ItemQuantitiesOnTripFromHouseProvider(String houseId)
    : this._internal(
        (ref) => itemQuantitiesOnTripFromHouse(
          ref as ItemQuantitiesOnTripFromHouseRef,
          houseId,
        ),
        from: itemQuantitiesOnTripFromHouseProvider,
        name: r'itemQuantitiesOnTripFromHouseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$itemQuantitiesOnTripFromHouseHash,
        dependencies: ItemQuantitiesOnTripFromHouseFamily._dependencies,
        allTransitiveDependencies:
            ItemQuantitiesOnTripFromHouseFamily._allTransitiveDependencies,
        houseId: houseId,
      );

  ItemQuantitiesOnTripFromHouseProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.houseId,
  }) : super.internal();

  final String houseId;

  @override
  Override overrideWith(
    Map<String, int> Function(ItemQuantitiesOnTripFromHouseRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ItemQuantitiesOnTripFromHouseProvider._internal(
        (ref) => create(ref as ItemQuantitiesOnTripFromHouseRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        houseId: houseId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Map<String, int>> createElement() {
    return _ItemQuantitiesOnTripFromHouseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemQuantitiesOnTripFromHouseProvider &&
        other.houseId == houseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, houseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ItemQuantitiesOnTripFromHouseRef
    on AutoDisposeProviderRef<Map<String, int>> {
  /// The parameter `houseId` of this provider.
  String get houseId;
}

class _ItemQuantitiesOnTripFromHouseProviderElement
    extends AutoDisposeProviderElement<Map<String, int>>
    with ItemQuantitiesOnTripFromHouseRef {
  _ItemQuantitiesOnTripFromHouseProviderElement(super.provider);

  @override
  String get houseId =>
      (origin as ItemQuantitiesOnTripFromHouseProvider).houseId;
}

String _$temporaryItemsInHouseHash() =>
    r'802e83e1b2f035913791be3b5d13f961beec4097';

/// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
///
/// Copied from [temporaryItemsInHouse].
@ProviderFor(temporaryItemsInHouse)
const temporaryItemsInHouseProvider = TemporaryItemsInHouseFamily();

/// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
///
/// Copied from [temporaryItemsInHouse].
class TemporaryItemsInHouseFamily extends Family<List<TripItem>> {
  /// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
  ///
  /// Copied from [temporaryItemsInHouse].
  const TemporaryItemsInHouseFamily();

  /// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
  ///
  /// Copied from [temporaryItemsInHouse].
  TemporaryItemsInHouseProvider call(String houseId) {
    return TemporaryItemsInHouseProvider(houseId);
  }

  @override
  TemporaryItemsInHouseProvider getProviderOverride(
    covariant TemporaryItemsInHouseProvider provider,
  ) {
    return call(provider.houseId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'temporaryItemsInHouseProvider';
}

/// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
///
/// Copied from [temporaryItemsInHouse].
class TemporaryItemsInHouseProvider
    extends AutoDisposeProvider<List<TripItem>> {
  /// Provider che fornisce gli items temporaneamente presenti in una casa (da viaggi attivi)
  ///
  /// Copied from [temporaryItemsInHouse].
  TemporaryItemsInHouseProvider(String houseId)
    : this._internal(
        (ref) =>
            temporaryItemsInHouse(ref as TemporaryItemsInHouseRef, houseId),
        from: temporaryItemsInHouseProvider,
        name: r'temporaryItemsInHouseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$temporaryItemsInHouseHash,
        dependencies: TemporaryItemsInHouseFamily._dependencies,
        allTransitiveDependencies:
            TemporaryItemsInHouseFamily._allTransitiveDependencies,
        houseId: houseId,
      );

  TemporaryItemsInHouseProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.houseId,
  }) : super.internal();

  final String houseId;

  @override
  Override overrideWith(
    List<TripItem> Function(TemporaryItemsInHouseRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TemporaryItemsInHouseProvider._internal(
        (ref) => create(ref as TemporaryItemsInHouseRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        houseId: houseId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<TripItem>> createElement() {
    return _TemporaryItemsInHouseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TemporaryItemsInHouseProvider && other.houseId == houseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, houseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TemporaryItemsInHouseRef on AutoDisposeProviderRef<List<TripItem>> {
  /// The parameter `houseId` of this provider.
  String get houseId;
}

class _TemporaryItemsInHouseProviderElement
    extends AutoDisposeProviderElement<List<TripItem>>
    with TemporaryItemsInHouseRef {
  _TemporaryItemsInHouseProviderElement(super.provider);

  @override
  String get houseId => (origin as TemporaryItemsInHouseProvider).houseId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
