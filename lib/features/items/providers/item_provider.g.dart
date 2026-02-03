// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$itemNotifierHash() => r'7d0b5ae176d9bf10bc9e2057c4670cd5c11ef357';

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

abstract class _$ItemNotifier extends BuildlessAsyncNotifier<List<ItemModel>> {
  late final String houseId;

  FutureOr<List<ItemModel>> build(String houseId);
}

/// See also [ItemNotifier].
@ProviderFor(ItemNotifier)
const itemNotifierProvider = ItemNotifierFamily();

/// See also [ItemNotifier].
class ItemNotifierFamily extends Family<AsyncValue<List<ItemModel>>> {
  /// See also [ItemNotifier].
  const ItemNotifierFamily();

  /// See also [ItemNotifier].
  ItemNotifierProvider call(String houseId) {
    return ItemNotifierProvider(houseId);
  }

  @override
  ItemNotifierProvider getProviderOverride(
    covariant ItemNotifierProvider provider,
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
  String? get name => r'itemNotifierProvider';
}

/// See also [ItemNotifier].
class ItemNotifierProvider
    extends AsyncNotifierProviderImpl<ItemNotifier, List<ItemModel>> {
  /// See also [ItemNotifier].
  ItemNotifierProvider(String houseId)
    : this._internal(
        () => ItemNotifier()..houseId = houseId,
        from: itemNotifierProvider,
        name: r'itemNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$itemNotifierHash,
        dependencies: ItemNotifierFamily._dependencies,
        allTransitiveDependencies:
            ItemNotifierFamily._allTransitiveDependencies,
        houseId: houseId,
      );

  ItemNotifierProvider._internal(
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
  FutureOr<List<ItemModel>> runNotifierBuild(covariant ItemNotifier notifier) {
    return notifier.build(houseId);
  }

  @override
  Override overrideWith(ItemNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ItemNotifierProvider._internal(
        () => create()..houseId = houseId,
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
  AsyncNotifierProviderElement<ItemNotifier, List<ItemModel>> createElement() {
    return _ItemNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemNotifierProvider && other.houseId == houseId;
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
mixin ItemNotifierRef on AsyncNotifierProviderRef<List<ItemModel>> {
  /// The parameter `houseId` of this provider.
  String get houseId;
}

class _ItemNotifierProviderElement
    extends AsyncNotifierProviderElement<ItemNotifier, List<ItemModel>>
    with ItemNotifierRef {
  _ItemNotifierProviderElement(super.provider);

  @override
  String get houseId => (origin as ItemNotifierProvider).houseId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
