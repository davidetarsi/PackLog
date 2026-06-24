// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'house_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$houseNotifierHash() => r'b28ba7e9cd08512c1a4a4f691a7241e99cd38e1b';

/// Notifier per la lista di case dell'utente.
///
/// Usa [SyncedCrudNotifier] per il pattern standard load → mutate → reload.
/// Ogni mutazione richiede automaticamente un sync push tramite l'hook
/// [onMutationSuccess].
///
/// Copied from [HouseNotifier].
@ProviderFor(HouseNotifier)
final houseNotifierProvider =
    AsyncNotifierProvider<HouseNotifier, List<HouseModel>>.internal(
      HouseNotifier.new,
      name: r'houseNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$houseNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$HouseNotifier = AsyncNotifier<List<HouseModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
