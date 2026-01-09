import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/house_model.dart';
import '../repositories/local_house_repository.dart';

part 'house_repository.g.dart';

@Riverpod(keepAlive: true)
Future<HouseRepository> houseRepository(Ref ref) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final repository = LocalHouseRepository(sharedPreferences);
  await repository.init();
  return repository;
}

abstract class HouseRepository {
  Future<bool> init();
  Future<void> addHouse(HouseModel model);
  Future<HouseModel> getHouseById(String id);
  Future<List<HouseModel>> getAllHouses();
  Future<bool> deleteHouse(String id);
  Future<void> updateHouse(HouseModel model);
}

