import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/house_model.dart';
import '../repositories/house_repository.dart';

part 'house_provider.g.dart';

/// Notifier per la lista di case dell'utente.
///
/// Usa [SyncedCrudNotifier] per il pattern standard load → mutate → reload.
/// Ogni mutazione richiede automaticamente un sync push tramite l'hook
/// [onMutationSuccess].
@Riverpod(keepAlive: true)
class HouseNotifier extends _$HouseNotifier
    with SyncedCrudNotifier<HouseModel> {
  HouseRepository get _repo => ref.read(houseRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  @override
  Future<List<HouseModel>> build() async {
    ref.watch(syncTriggerProvider);
    return _repo.getAllHouses();
  }

  @override
  void onMutationSuccess(List<HouseModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
  }

  Future<void> addHouse(HouseModel model) => mutate(
    operation: () => _repo.addHouse(model),
    reload: _repo.getAllHouses,
    onSuccess: (houses) => _analytics.trackHouseCreated(
      houseId: model.id,
      totalHouses: houses.length,
    ),
  );

  Future<void> updateHouse(HouseModel model) => mutate(
    operation: () => _repo.updateHouse(model),
    reload: _repo.getAllHouses,
    onSuccess: (_) => _analytics.trackHouseUpdated(),
  );

  Future<void> deleteHouse(String id) => mutate(
    operation: () => _repo.deleteHouse(id),
    reload: _repo.getAllHouses,
    onSuccess: (_) => _analytics.trackHouseDeleted(),
  );

  Future<void> refresh() => mutate(
    // Nessuna operation: solo reload.
    operation: () async {},
    reload: _repo.getAllHouses,
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );

  Future<String> duplicateHouse(String houseId) async {
    late String newId;
    await mutate(
      operation: () async {
        final original = await _repo.getHouseById(houseId);
        final now = DateTime.now();
        newId = const Uuid().v4();
        final copy = original.copyWith(
          id: newId,
          isPrimary: false,
          createdAt: now,
          updatedAt: now,
        );
        await _repo.addHouse(copy);
      },
      reload: _repo.getAllHouses,
      onSuccess: (_) => _analytics.trackHouseDuplicated(),
    );
    return newId;
  }

  /// Imposta una casa come principale.
  ///
  /// Delega al DAO: 4 query bulk in transazione anziché N update in loop.
  /// Vedi [HousesDao.setPrimaryHouse] per la gestione di pendingCreate.
  Future<void> setPrimaryHouse(String houseId) => mutate(
    operation: () => _repo.setPrimaryHouse(houseId),
    reload: _repo.getAllHouses,
  );
}
