// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'house_deletion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$canDeleteHouseHash() => r'9f2b62b7300fdfe98c46258d9d72979a7047dc7a';

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

/// Provider che verifica se una casa può essere eliminata
///
/// Copied from [canDeleteHouse].
@ProviderFor(canDeleteHouse)
const canDeleteHouseProvider = CanDeleteHouseFamily();

/// Provider che verifica se una casa può essere eliminata
///
/// Copied from [canDeleteHouse].
class CanDeleteHouseFamily extends Family<AsyncValue<HouseDeletionBlocker>> {
  /// Provider che verifica se una casa può essere eliminata
  ///
  /// Copied from [canDeleteHouse].
  const CanDeleteHouseFamily();

  /// Provider che verifica se una casa può essere eliminata
  ///
  /// Copied from [canDeleteHouse].
  CanDeleteHouseProvider call(String houseId) {
    return CanDeleteHouseProvider(houseId);
  }

  @override
  CanDeleteHouseProvider getProviderOverride(
    covariant CanDeleteHouseProvider provider,
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
  String? get name => r'canDeleteHouseProvider';
}

/// Provider che verifica se una casa può essere eliminata
///
/// Copied from [canDeleteHouse].
class CanDeleteHouseProvider
    extends AutoDisposeFutureProvider<HouseDeletionBlocker> {
  /// Provider che verifica se una casa può essere eliminata
  ///
  /// Copied from [canDeleteHouse].
  CanDeleteHouseProvider(String houseId)
    : this._internal(
        (ref) => canDeleteHouse(ref as CanDeleteHouseRef, houseId),
        from: canDeleteHouseProvider,
        name: r'canDeleteHouseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$canDeleteHouseHash,
        dependencies: CanDeleteHouseFamily._dependencies,
        allTransitiveDependencies:
            CanDeleteHouseFamily._allTransitiveDependencies,
        houseId: houseId,
      );

  CanDeleteHouseProvider._internal(
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
    FutureOr<HouseDeletionBlocker> Function(CanDeleteHouseRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CanDeleteHouseProvider._internal(
        (ref) => create(ref as CanDeleteHouseRef),
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
  AutoDisposeFutureProviderElement<HouseDeletionBlocker> createElement() {
    return _CanDeleteHouseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CanDeleteHouseProvider && other.houseId == houseId;
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
mixin CanDeleteHouseRef on AutoDisposeFutureProviderRef<HouseDeletionBlocker> {
  /// The parameter `houseId` of this provider.
  String get houseId;
}

class _CanDeleteHouseProviderElement
    extends AutoDisposeFutureProviderElement<HouseDeletionBlocker>
    with CanDeleteHouseRef {
  _CanDeleteHouseProviderElement(super.provider);

  @override
  String get houseId => (origin as CanDeleteHouseProvider).houseId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
