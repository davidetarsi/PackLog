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
}
