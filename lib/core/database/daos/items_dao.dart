import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/items_table.dart';

part 'items_dao.g.dart';

/// DAO per le operazioni CRUD sugli oggetti.
@DriftAccessor(tables: [Items])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  /// Ottiene tutti gli oggetti
  Future<List<Item>> getAllItems() => select(items).get();

  /// Ottiene tutti gli oggetti come stream (per reattività)
  Stream<List<Item>> watchAllItems() => select(items).watch();

  /// Ottiene gli oggetti di una casa specifica
  Future<List<Item>> getItemsByHouseId(String houseId) {
    return (select(items)..where((i) => i.houseId.equals(houseId))).get();
  }

  /// Ottiene gli oggetti di una casa come stream
  Stream<List<Item>> watchItemsByHouseId(String houseId) {
    return (select(items)..where((i) => i.houseId.equals(houseId))).watch();
  }

  /// Ottiene un oggetto per ID
  Future<Item?> getItemById(String id) {
    return (select(items)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce un nuovo oggetto
  Future<int> insertItem(ItemsCompanion item) {
    return into(items).insert(item);
  }

  /// Aggiorna un oggetto esistente
  Future<bool> updateItem(ItemsCompanion item) {
    return update(items).replace(item);
  }

  /// Elimina un oggetto per ID
  Future<int> deleteItem(String id) {
    return (delete(items)..where((i) => i.id.equals(id))).go();
  }

  /// Elimina tutti gli oggetti di una casa
  Future<int> deleteItemsByHouseId(String houseId) {
    return (delete(items)..where((i) => i.houseId.equals(houseId))).go();
  }

  /// Inserisce multiple oggetti (per migrazione)
  Future<void> insertMultipleItems(List<ItemsCompanion> itemsList) async {
    await batch((batch) {
      batch.insertAll(items, itemsList);
    });
  }
}
