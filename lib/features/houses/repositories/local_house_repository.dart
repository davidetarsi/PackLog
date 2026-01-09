import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/house_model.dart';
import '../repositories/house_repository.dart';
import '../../../shared/constants/app_constants.dart';

class LocalHouseRepository implements HouseRepository {
  final SharedPreferences _sharedPreferences;
  
  LocalHouseRepository(this._sharedPreferences);
  
  @override
  Future<bool> init() async {
    return true;
  }
  
  @override
  Future<void> addHouse(HouseModel model) async {
    final houses = await getAllHouses();
    final updatedHouses = [...houses, model];
    await _saveHouses(updatedHouses);
  }

  @override
  Future<HouseModel> getHouseById(String id) async {
    final houses = await getAllHouses();
    return houses.firstWhere((house) => house.id == id);
  }

  @override
  Future<List<HouseModel>> getAllHouses() async {
    final housesJson = _sharedPreferences.getStringList(AppConstants.housesKey) ?? [];
    return housesJson
        .map((json) => HouseModel.fromJson(jsonDecode(json)))
        .toList();
  }

  @override
  Future<bool> deleteHouse(String id) async {
    final houses = await getAllHouses();
    houses.removeWhere((house) => house.id == id);
    await _saveHouses(houses);
    return true;
  }

  @override
  Future<void> updateHouse(HouseModel model) async {
    final houses = await getAllHouses();
    final index = houses.indexWhere((h) => h.id == model.id);
    if (index != -1) {
      final updatedHouse = model.copyWith(updatedAt: DateTime.now());
      houses[index] = updatedHouse;
      await _saveHouses(houses);
    }
  }

  Future<void> _saveHouses(List<HouseModel> houses) async {
    final housesJson = houses.map((h) => jsonEncode(h.toJson())).toList();
    await _sharedPreferences.setStringList(AppConstants.housesKey, housesJson);
  }
}

