import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../model/space_model.dart';
import '../repositories/space_repository.dart';

part 'space_provider.g.dart';

/// Notifier family per gli spazi di una specifica casa.
///
/// Pattern allineato a [ItemNotifier]: una sola sorgente di verità per
/// casa, le mutazioni ricaricano la lista filtrata e si propagano
/// automaticamente ai consumer senza bisogno di `ref.invalidate` manuali.
@Riverpod(keepAlive: true)
class SpaceNotifier extends _$SpaceNotifier {
  SpaceRepository? repository;

  @override
  Future<List<SpaceModel>> build(String houseId) async {
    repository = ref.watch(spaceRepositoryProvider);
    return repository!.getSpacesByHouseId(houseId);
  }

  Future<void> addSpace(SpaceModel model) async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addSpace(model);
      final spaces = await repository!.getSpacesByHouseId(houseId);
      state = AsyncData(spaces);
      ref.read(coreAnalyticsServiceProvider).trackSpaceCreated();
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateSpace(SpaceModel model) async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateSpace(model);
      final spaces = await repository!.getSpacesByHouseId(houseId);
      state = AsyncData(spaces);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteSpace(String id) async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteSpace(id);
      final spaces = await repository!.getSpacesByHouseId(houseId);
      state = AsyncData(spaces);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refresh() async {
    repository ??= ref.read(spaceRepositoryProvider);
    state = const AsyncLoading();
    try {
      final spaces = await repository!.getSpacesByHouseId(houseId);
      state = AsyncData(spaces);
    } catch (error, stackTrace) {
      // No rethrow: refresh() is wired to ErrorState.onRetry (VoidCallback).
      state = AsyncError(error, stackTrace);
    }
  }
}

// Nota: l'ex [spacesByHouseProvider] (FutureProvider derivato) è stato
// eliminato — la stessa funzione è ora servita da [spaceNotifierProvider]
// con la signature family `(String houseId)`. Eliminato anche il bisogno
// di `ref.invalidate(spaceNotifierProvider(...))` dopo le mutazioni: il
// notifier family aggiorna il suo state direttamente.

/// Provider per contare gli spazi di una casa.
@riverpod
Future<int> spaceCountByHouse(Ref ref, String houseId) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.countSpacesByHouse(houseId);
}
