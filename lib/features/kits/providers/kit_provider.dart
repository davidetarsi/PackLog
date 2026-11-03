import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/sync/sync_provider.dart';
import '../model/kit_model.dart';
import '../repositories/kit_repository.dart';

part 'kit_provider.g.dart';

/// I kit di una casa. Lo stato segue lo stream di `watchKits`: ogni modifica
/// ai kit, agli oggetti o alla casa (anche fatta altrove) lo aggiorna da sola.
/// Le mutazioni scrivono soltanto e chiedono il sync; i limiti
/// (`KitLimitException`) arrivano al chiamante e la lista resta intatta.
@Riverpod(keepAlive: true)
class KitNotifier extends _$KitNotifier {
  KitRepository get _repo => ref.read(kitRepositoryProvider);

  @override
  Future<List<KitModel>> build(String houseId) {
    ref.watch(syncTriggerProvider);
    final first = Completer<List<KitModel>>();
    final sub = _repo
        .watchKits(houseId)
        .listen(
          (kits) {
            if (!first.isCompleted) {
              first.complete(kits);
            } else {
              state = AsyncData(kits);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!first.isCompleted) {
              first.completeError(error, stack);
            } else {
              state = AsyncError(error, stack);
            }
          },
        );
    ref.onDispose(sub.cancel);
    return first.future;
  }

  Future<T> _write<T>(Future<T> Function() operation) async {
    final result = await operation();
    ref.read(syncOrchestratorProvider).requestSync();
    return result;
  }

  Future<KitModel> createKit({
    required String name,
    List<String> activities = const [],
    List<String> transports = const [],
  }) => _write(
    () => _repo.createKit(
      houseId: houseId,
      name: name,
      activities: activities,
      transports: transports,
    ),
  );

  Future<void> updateKit(KitModel kit) => _write(() => _repo.updateKit(kit));

  Future<void> deleteKit(String id) => _write(() => _repo.deleteKit(id));

  Future<void> addItems(String kitId, Map<String, int> copiesByItemId) =>
      _write(() => _repo.addItems(kitId, copiesByItemId));

  Future<void> removeItem(String kitId, String itemId) =>
      _write(() => _repo.removeItem(kitId, itemId));

  Future<KitModel> recordYes(String kitId, List<String> uses) =>
      _write(() => _repo.recordYes(kitId, uses));

  Future<void> learnUse(String kitId, String use) =>
      _write(() => _repo.learnUse(kitId, use));

  Future<void> refuseUse(String kitId, String use) =>
      _write(() => _repo.refuseUse(kitId, use));
}
