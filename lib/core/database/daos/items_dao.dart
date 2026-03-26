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

  // === Space Filtering Methods ===

  /// Ottiene gli oggetti di una casa filtrati per spazio specifico
  Future<List<Item>> getItemsBySpaceId(String houseId, String spaceId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.spaceId.equals(spaceId)))
        .get();
  }

  /// Ottiene gli oggetti nel pool generale di una casa (spaceId == null)
  Future<List<Item>> getItemsInGeneralPool(String houseId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.spaceId.isNull()))
        .get();
  }

  /// Stream degli oggetti filtrati per spazio
  Stream<List<Item>> watchItemsBySpaceId(String houseId, String spaceId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.spaceId.equals(spaceId)))
        .watch();
  }

  /// Stream degli oggetti nel pool generale
  Stream<List<Item>> watchItemsInGeneralPool(String houseId) {
    return (select(items)
          ..where((i) => i.houseId.equals(houseId) & i.spaceId.isNull()))
        .watch();
  }

  /// Conta gli oggetti in uno spazio specifico
  Future<int> countItemsBySpace(String spaceId) async {
    final query = selectOnly(items)
      ..addColumns([items.id.count()])
      ..where(items.spaceId.equals(spaceId));
    
    final result = await query.getSingleOrNull();
    return result?.read(items.id.count()) ?? 0;
  }

  /// Conta gli oggetti nel pool generale di una casa
  Future<int> countItemsInGeneralPool(String houseId) async {
    final query = selectOnly(items)
      ..addColumns([items.id.count()])
      ..where(items.houseId.equals(houseId) & items.spaceId.isNull());
    
    final result = await query.getSingleOrNull();
    return result?.read(items.id.count()) ?? 0;
  }

  /// Sposta un set di oggetti da [fromHouseId] a [toHouseId] in una singola
  /// query SQL:
  /// `UPDATE items SET house_id = ? WHERE id IN (?) AND house_id = ?`
  ///
  /// Il filtro `AND house_id = fromHouseId` è **critico per la correttezza**:
  /// garantisce che vengano spostati solo gli item che si trovano *ancora*
  /// nella casa di partenza del viaggio. Se un item è già stato trasferito
  /// (viaggio precedente completato) o si trova in un'altra casa per qualsiasi
  /// motivo, la query lo ignora senza effetti collaterali.
  ///
  /// Azzera anche [spaceId]: gli oggetti arrivano nel pool generale della casa
  /// di destinazione e l'utente potrà assegnarli a uno spazio in seguito.
  Future<void> moveItemsToHouse(
    List<String> itemIds,
    String fromHouseId,
    String toHouseId,
  ) async {
    if (itemIds.isEmpty) return;
    await (update(items)
          ..where(
            (t) => t.id.isIn(itemIds) & t.houseId.equals(fromHouseId),
          ))
        .write(
      ItemsCompanion(
        houseId: Value(toHouseId),
        spaceId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
