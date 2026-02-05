import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/house_model.dart';
import '../repositories/house_repository.dart';

part 'house_provider.g.dart';

@Riverpod(keepAlive: true)
class HouseNotifier extends _$HouseNotifier {
  HouseRepository? repository;

  @override
  Future<List<HouseModel>> build() async {
    repository = ref.watch(houseRepositoryProvider);
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
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
