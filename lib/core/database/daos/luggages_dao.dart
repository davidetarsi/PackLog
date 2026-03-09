import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/luggages_table.dart';
import '../tables/trip_luggage_entries_table.dart';

part 'luggages_dao.g.dart';

/// DAO per le operazioni CRUD sui bagagli.
@DriftAccessor(tables: [Luggages, TripLuggageEntries])
class LuggagesDao extends DatabaseAccessor<AppDatabase> with _$LuggagesDaoMixin {
  LuggagesDao(super.db);

  /// Ottiene tutti i bagagli
  Future<List<Luggage>> getAllLuggages() => select(luggages).get();

  /// Ottiene tutti i bagagli di una casa specifica
  Future<List<Luggage>> getLuggagesByHouse(String houseId) {
    return (select(luggages)..where((l) => l.houseId.equals(houseId))).get();
  }

  /// Ottiene tutti i bagagli di una casa come stream (per reattività)
  Stream<List<Luggage>> watchLuggagesByHouse(String houseId) {
    return (select(luggages)..where((l) => l.houseId.equals(houseId))).watch();
  }

  /// Ottiene un bagaglio per ID
  Future<Luggage?> getLuggageById(String id) {
    return (select(luggages)..where((l) => l.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce un nuovo bagaglio
  Future<int> insertLuggage(LuggagesCompanion luggage) {
    return into(luggages).insert(luggage);
  }

  /// Aggiorna un bagaglio esistente
  Future<bool> updateLuggage(LuggagesCompanion luggage) {
    return update(luggages).replace(luggage);
  }

  /// Elimina un bagaglio per ID
  /// 
  /// Nota: Cascade delete configurato nella junction table,
  /// quindi le entry in trip_luggage_entries verranno eliminate automaticamente.
  Future<int> deleteLuggage(String id) {
    return (delete(luggages)..where((l) => l.id.equals(id))).go();
  }

  /// Ottiene i bagagli associati a un viaggio specifico tramite junction table.
  /// 
  /// Esegue un JOIN tra luggages e trip_luggage_entries.
  Future<List<Luggage>> getLuggagesByTrip(String tripId) async {
    final query = select(luggages).join([
      innerJoin(
        tripLuggageEntries,
        tripLuggageEntries.luggageId.equalsExp(luggages.id),
      ),
    ])..where(tripLuggageEntries.tripId.equals(tripId));

    final results = await query.get();
    return results.map((row) => row.readTable(luggages)).toList();
  }

  /// Associa un bagaglio a un viaggio (inserisce entry nella junction table).
  Future<void> linkLuggageToTrip(String tripId, String luggageId) async {
    await into(tripLuggageEntries).insert(
      TripLuggageEntriesCompanion.insert(
        tripId: tripId,
        luggageId: luggageId,
      ),
    );
  }

  /// Rimuove l'associazione tra un bagaglio e un viaggio.
  Future<void> unlinkLuggageFromTrip(String tripId, String luggageId) async {
    await (delete(tripLuggageEntries)
          ..where((entry) =>
              entry.tripId.equals(tripId) & entry.luggageId.equals(luggageId)))
        .go();
  }

  /// Sostituisce tutti i bagagli associati a un viaggio.
  /// 
  /// Esegue in transaction:
  /// 1. Elimina tutte le entry esistenti per il trip
  /// 2. Inserisce le nuove entry
  Future<void> replaceTripLuggages(
    String tripId,
    List<String> luggageIds,
  ) async {
    await transaction(() async {
      // Elimina tutte le associazioni esistenti
      await (delete(tripLuggageEntries)
            ..where((entry) => entry.tripId.equals(tripId)))
          .go();

      // Inserisce le nuove associazioni
      if (luggageIds.isNotEmpty) {
        await batch((batch) {
          for (final luggageId in luggageIds) {
            batch.insert(
              tripLuggageEntries,
              TripLuggageEntriesCompanion.insert(
                tripId: tripId,
                luggageId: luggageId,
              ),
            );
          }
        });
      }
    });
  }

  /// Conta il numero di bagagli in una casa
  Future<int> countLuggagesByHouse(String houseId) async {
    final query = selectOnly(luggages)
      ..addColumns([luggages.id.count()])
      ..where(luggages.houseId.equals(houseId));
    
    final result = await query.getSingleOrNull();
    return result?.read(luggages.id.count()) ?? 0;
  }
}
