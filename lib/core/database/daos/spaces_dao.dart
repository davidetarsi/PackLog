import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/spaces_table.dart';

part 'spaces_dao.g.dart';

/// DAO per le operazioni CRUD sugli spazi/armadi.
@DriftAccessor(tables: [Spaces])
class SpacesDao extends DatabaseAccessor<AppDatabase> with _$SpacesDaoMixin {
  SpacesDao(super.db);

  /// Ottiene tutti gli spazi
  Future<List<Space>> getAllSpaces() => select(spaces).get();

  /// Ottiene tutti gli spazi di una casa specifica
  Future<List<Space>> getSpacesByHouse(String houseId) {
    return (select(spaces)..where((s) => s.houseId.equals(houseId))).get();
  }

  /// Ottiene tutti gli spazi di una casa come stream (per reattività)
  Stream<List<Space>> watchSpacesByHouse(String houseId) {
    return (select(spaces)..where((s) => s.houseId.equals(houseId))).watch();
  }

  /// Ottiene uno spazio per ID
  Future<Space?> getSpaceById(String id) {
    return (select(spaces)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce un nuovo spazio
  Future<int> insertSpace(SpacesCompanion space) {
    return into(spaces).insert(space);
  }

  /// Aggiorna uno spazio esistente
  Future<bool> updateSpace(SpacesCompanion space) {
    return update(spaces).replace(space);
  }

  /// Elimina uno spazio per ID
  /// 
  /// Nota: ON DELETE SET NULL è configurato nella FK,
  /// quindi gli items con questo spaceId torneranno al pool generale.
  Future<int> deleteSpace(String id) {
    return (delete(spaces)..where((s) => s.id.equals(id))).go();
  }

  /// Conta il numero di spazi in una casa
  Future<int> countSpacesByHouse(String houseId) async {
    final query = selectOnly(spaces)
      ..addColumns([spaces.id.count()])
      ..where(spaces.houseId.equals(houseId));
    
    final result = await query.getSingleOrNull();
    return result?.read(spaces.id.count()) ?? 0;
  }
}
