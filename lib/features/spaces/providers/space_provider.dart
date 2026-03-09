import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/space_model.dart';
import '../repositories/space_repository.dart';

part 'space_provider.g.dart';

/// Notifier globale per tutti gli spazi dell'app.
/// 
/// Gestisce CRUD operations con state caching e invalidation automatica.
@Riverpod(keepAlive: true)
class SpaceNotifier extends _$SpaceNotifier {
  SpaceRepository? repository;

  @override
  Future<List<SpaceModel>> build() async {
    repository = ref.watch(spaceRepositoryProvider);
    final spaces = await repository!.getAllSpaces();
    return spaces;
  }

  Future<void> addSpace(SpaceModel model) async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addSpace(model);
      final spaces = await repository!.getAllSpaces();
      state = AsyncData(spaces);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateSpace(SpaceModel model) async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateSpace(model);
      final spaces = await repository!.getAllSpaces();
      state = AsyncData(spaces);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteSpace(String id) async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteSpace(id);
      final spaces = await repository!.getAllSpaces();
      state = AsyncData(spaces);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      final spaces = await repository!.getAllSpaces();
      state = AsyncData(spaces);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

/// Family provider per ottenere gli spazi di una casa specifica.
/// 
/// Filtra gli spazi in base all'houseId e li mantiene in cache.
@riverpod
Future<List<SpaceModel>> spacesByHouse(SpacesByHouseRef ref, String houseId) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.getSpacesByHouseId(houseId);
}

/// Provider per contare gli spazi di una casa.
@riverpod
Future<int> spaceCountByHouse(SpaceCountByHouseRef ref, String houseId) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.countSpacesByHouse(houseId);
}
