import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/houses_table.dart';

part 'houses_dao.g.dart';

/// DAO per le operazioni CRUD sulle case.
@DriftAccessor(tables: [Houses])
class HousesDao extends DatabaseAccessor<AppDatabase> with _$HousesDaoMixin {
  HousesDao(super.db);

  /// Ottiene tutte le case
  Future<List<House>> getAllHouses() => select(houses).get();

  /// Ottiene tutte le case come stream (per reattività)
  Stream<List<House>> watchAllHouses() => select(houses).watch();

  /// Ottiene una casa per ID
  Future<House?> getHouseById(String id) {
    return (select(houses)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce una nuova casa
  Future<int> insertHouse(HousesCompanion house) {
    return into(houses).insert(house);
  }

  /// Aggiorna una casa esistente
  Future<bool> updateHouse(HousesCompanion house) {
    return update(houses).replace(house);
  }

  /// Elimina una casa per ID
  Future<int> deleteHouse(String id) {
    return (delete(houses)..where((h) => h.id.equals(id))).go();
  }

  /// Inserisce multiple case (per migrazione)
  Future<void> insertMultipleHouses(List<HousesCompanion> housesList) async {
    await batch((batch) {
      batch.insertAll(houses, housesList);
    });
  }
}
