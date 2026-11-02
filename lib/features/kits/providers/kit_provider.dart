import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/kit_model.dart';
import '../repositories/kit_repository.dart';

part 'kit_provider.g.dart';

/// I kit di una casa. Le mutazioni scrivono e ricaricano la lista; i limiti
/// (`KitLimitException`) arrivano al chiamante, la lista resta intatta.
@Riverpod(keepAlive: true)
class KitNotifier extends _$KitNotifier with SyncedCrudNotifier<KitModel> {
  KitRepository get _repo => ref.read(kitRepositoryProvider);

  Future<List<KitModel>> _load() => _repo.watchKits(houseId).first;

  @override
  Future<List<KitModel>> build(String houseId) async {
    ref.watch(syncTriggerProvider);
    return _load();
  }

  @override
  void onMutationSuccess(List<KitModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
  }

  Future<KitModel> createKit({
    required String name,
    List<String> activities = const [],
    List<String> transports = const [],
  }) async {
    late KitModel created;
    await mutate(
      operation: () async => created = await _repo.createKit(
        houseId: houseId,
        name: name,
        activities: activities,
        transports: transports,
      ),
      reload: _load,
      rethrowOnly: true,
    );
    return created;
  }

  Future<void> updateKit(KitModel kit) => mutate(
    operation: () => _repo.updateKit(kit),
    reload: _load,
    rethrowOnly: true,
  );

  Future<void> deleteKit(String id) => mutate(
    operation: () => _repo.deleteKit(id),
    reload: _load,
    rethrowOnly: true,
  );

  Future<void> addItems(String kitId, Map<String, int> copiesByItemId) =>
      mutate(
        operation: () => _repo.addItems(kitId, copiesByItemId),
        reload: _load,
        rethrowOnly: true,
      );

  Future<void> removeItem(String kitId, String itemId) => mutate(
    operation: () => _repo.removeItem(kitId, itemId),
    reload: _load,
    rethrowOnly: true,
  );

  Future<KitModel> recordYes(String kitId, List<String> uses) async {
    late KitModel updated;
    await mutate(
      operation: () async => updated = await _repo.recordYes(kitId, uses),
      reload: _load,
      rethrowOnly: true,
    );
    return updated;
  }

  Future<void> learnUse(String kitId, String use) => mutate(
    operation: () => _repo.learnUse(kitId, use),
    reload: _load,
    rethrowOnly: true,
  );

  Future<void> refuseUse(String kitId, String use) => mutate(
    operation: () => _repo.refuseUse(kitId, use),
    reload: _load,
    rethrowOnly: true,
  );
}
