import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/house_model.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/services/persistence_services.dart';
import 'drift_house_repository.dart';

part 'house_repository.g.dart';

@Riverpod(keepAlive: true)
HouseRepository houseRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return DriftHouseRepository(database.housesDao, dbService);
}

abstract class HouseRepository {
  Future<bool> init();
  Future<void> addHouse(HouseModel model);
  Future<HouseModel> getHouseById(String id);
  Future<List<HouseModel>> getAllHouses();
  Future<bool> deleteHouse(String id);
  Future<void> updateHouse(HouseModel model);
}
