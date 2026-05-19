import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../model/house_model.dart';
import '../repositories/house_repository.dart';

part 'house_provider.g.dart';

@Riverpod(keepAlive: true)
class HouseNotifier extends _$HouseNotifier {
  HouseRepository? repository;

  @override
  Future<List<HouseModel>> build() async {
    repository = ref.watch(houseRepositoryProvider);
    ref.watch(syncTriggerProvider);
    final houses = await repository!.getAllHouses();
    return houses;
  }

  Future<void> addHouse(HouseModel model) async {
    repository ??= ref.read(houseRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addHouse(model);
      final houses = await repository!.getAllHouses();
      state = AsyncData(houses);
      ref
          .read(coreAnalyticsServiceProvider)
          .trackHouseCreated(houseId: model.id, totalHouses: houses.length);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateHouse(HouseModel model) async {
    repository ??= ref.read(houseRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateHouse(model);
      final houses = await repository!.getAllHouses();
      state = AsyncData(houses);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteHouse(String id) async {
    repository ??= ref.read(houseRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteHouse(id);
      final houses = await repository!.getAllHouses();
      state = AsyncData(houses);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    repository ??= ref.read(houseRepositoryProvider);
    state = const AsyncLoading();
    try {
      final houses = await repository!.getAllHouses();
      state = AsyncData(houses);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<String> duplicateHouse(String houseId) async {
    repository ??= ref.read(houseRepositoryProvider);
    state = const AsyncLoading();
    try {
      final original = await repository!.getHouseById(houseId);
      final now = DateTime.now();
      final newId = const Uuid().v4();
      final copy = original.copyWith(
        id: newId,
        isPrimary: false,
        createdAt: now,
        updatedAt: now,
      );
      await repository!.addHouse(copy);
      final houses = await repository!.getAllHouses();
      state = AsyncData(houses);
      ref.read(syncOrchestratorProvider).requestSync();
      return newId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Imposta una casa come principale.
  /// Rimuove automaticamente lo stato "principale" da tutte le altre case.
  Future<void> setPrimaryHouse(String houseId) async {
    repository ??= ref.read(houseRepositoryProvider);
    state = const AsyncLoading();
    try {
      final houses = await repository!.getAllHouses();

      // Aggiorna ogni casa: solo quella selezionata sarà isPrimary = true
      for (final house in houses) {
        if (house.isPrimary && house.id != houseId) {
          // Rimuovi isPrimary da altre case
          await repository!.updateHouse(house.copyWith(isPrimary: false));
        } else if (!house.isPrimary && house.id == houseId) {
          // Imposta isPrimary sulla casa selezionata
          await repository!.updateHouse(house.copyWith(isPrimary: true));
        }
      }

      // Ricarica le case aggiornate
      final updatedHouses = await repository!.getAllHouses();
      state = AsyncData(updatedHouses);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
