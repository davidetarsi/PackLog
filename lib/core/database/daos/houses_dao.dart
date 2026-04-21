import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/houses_table.dart';
import '../tables/items_table.dart';
import '../tables/spaces_table.dart';
import '../tables/luggages_table.dart';

part 'houses_dao.g.dart';

/// DAO per le operazioni CRUD sulle case.
@DriftAccessor(tables: [Houses, Items, Spaces, Luggages])
class HousesDao extends DatabaseAccessor<AppDatabase> with _$HousesDaoMixin {
  HousesDao(super.db);

  /// Ottiene tutte le case non eliminate
  Future<List<House>> getAllHouses() =>
      (select(houses)..where((h) => h.isDeleted.equals(false))).get();

  /// Ottiene tutte le case non eliminate come stream
  Stream<List<House>> watchAllHouses() =>
      (select(houses)..where((h) => h.isDeleted.equals(false))).watch();

  /// Ottiene una casa per ID (solo se non eliminata)
  Future<House?> getHouseById(String id) {
    return (select(houses)
          ..where((h) => h.id.equals(id) & h.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserisce una nuova casa
  Future<int> insertHouse(HousesCompanion house) {
    return into(houses).insert(house);
  }

  /// Aggiorna una casa esistente
  Future<bool> updateHouse(HousesCompanion house) {
    return update(houses).replace(house);
  }

  /// Soft-delete di una casa con cascade manuale su Items, Spaces e Luggages.
  ///
  /// Sostituisce la DELETE fisica (con CASCADE SQLite) con una transazione
  /// che imposta [isDeleted = true] sulla casa e su tutti i record dipendenti
  /// non già eliminati. Il database mantiene le righe per consentire la
  /// propagazione al cloud prima della purga definitiva.
  Future<int> deleteHouse(String id) async {
    return transaction(() async {
      final now = DateTime.now();

      // Cascade soft-delete: items della casa
      await (update(items)
            ..where((i) => i.houseId.equals(id) & i.isDeleted.equals(false)))
          .write(
        ItemsCompanion(isDeleted: const Value(true), updatedAt: Value(now)),
      );

      // Cascade soft-delete: spazi della casa
      await (update(spaces)
            ..where((s) => s.houseId.equals(id) & s.isDeleted.equals(false)))
          .write(
        SpacesCompanion(isDeleted: const Value(true), updatedAt: Value(now)),
      );

      // Cascade soft-delete: bagagli della casa
      await (update(luggages)
            ..where((l) => l.houseId.equals(id) & l.isDeleted.equals(false)))
          .write(
        LuggagesCompanion(isDeleted: const Value(true), updatedAt: Value(now)),
      );

      // Soft-delete della casa stessa
      return (update(houses)..where((h) => h.id.equals(id))).write(
        HousesCompanion(isDeleted: const Value(true), updatedAt: Value(now)),
      );
    });
  }

  /// Inserisce multiple case (per migrazione)
  Future<void> insertMultipleHouses(List<HousesCompanion> housesList) async {
    await batch((batch) {
      batch.insertAll(houses, housesList);
    });
  }
}
