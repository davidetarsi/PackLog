import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/space_model.dart';
import '../repositories/space_repository.dart';

part 'space_provider.g.dart';

/// Notifier family per gli spazi di una specifica casa.
///
/// Pattern allineato a [ItemNotifier]: una sola sorgente di verità per
/// casa, le mutazioni ricaricano la lista filtrata e si propagano
/// automaticamente ai consumer senza bisogno di `ref.invalidate` manuali.
@Riverpod(keepAlive: true)
class SpaceNotifier extends _$SpaceNotifier
    with SyncedCrudNotifier<SpaceModel> {
  SpaceRepository get _repo => ref.read(spaceRepositoryProvider);

  @override
  Future<List<SpaceModel>> build(String houseId) =>
      _repo.getSpacesByHouseId(houseId);

  @override
  void onMutationSuccess(List<SpaceModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
  }

  Future<void> addSpace(SpaceModel model) => mutate(
    operation: () => _repo.addSpace(model),
    reload: () => _repo.getSpacesByHouseId(houseId),
    rethrowOnly: true,
    onSuccess: (_) =>
        ref.read(coreAnalyticsServiceProvider).trackSpaceCreated(),
  );

  Future<void> updateSpace(SpaceModel model) => mutate(
    operation: () => _repo.updateSpace(model),
    reload: () => _repo.getSpacesByHouseId(houseId),
    rethrowOnly: true,
  );

  Future<void> deleteSpace(String id) => mutate(
    operation: () => _repo.deleteSpace(id),
    reload: () => _repo.getSpacesByHouseId(houseId),
    rethrowOnly: true,
  );

  Future<void> refresh() => mutate(
    operation: () async {},
    reload: () => _repo.getSpacesByHouseId(houseId),
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );
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
