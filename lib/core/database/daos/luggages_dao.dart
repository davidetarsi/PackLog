import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/luggages_table.dart';
import '../tables/trip_luggage_entries_table.dart';

part 'luggages_dao.g.dart';

/// DAO per le operazioni CRUD sui bagagli.
@DriftAccessor(tables: [Luggages, TripLuggageEntries])
class LuggagesDao extends DatabaseAccessor<AppDatabase>
    with _$LuggagesDaoMixin {
  LuggagesDao(super.db);

  /// Ottiene tutti i bagagli non eliminati
  Future<List<Luggage>> getAllLuggages() =>
      (select(luggages)..where((l) => l.isDeleted.equals(false))).get();

  /// Ottiene tutti i bagagli non eliminati di una casa specifica
  Future<List<Luggage>> getLuggagesByHouse(String houseId) {
    return (select(luggages)
          ..where((l) => l.houseId.equals(houseId) & l.isDeleted.equals(false)))
        .get();
  }

  /// Ottiene tutti i bagagli non eliminati di una casa come stream
  Stream<List<Luggage>> watchLuggagesByHouse(String houseId) {
    return (select(luggages)
          ..where((l) => l.houseId.equals(houseId) & l.isDeleted.equals(false)))
        .watch();
  }

  /// Ottiene un bagaglio per ID (solo se non eliminato)
  Future<Luggage?> getLuggageById(String id) {
    return (select(luggages)
          ..where((l) => l.id.equals(id) & l.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserisce un nuovo bagaglio
  Future<int> insertLuggage(LuggagesCompanion luggage) {
    return into(luggages).insert(luggage);
  }

  /// Aggiorna un bagaglio esistente
  Future<bool> updateLuggage(LuggagesCompanion luggage) {
    return update(luggages).replace(luggage);
  }

  /// Soft-delete di un bagaglio.
  ///
  /// Le entry in [TripLuggageEntries] restano fisicamente nel DB (junction
  /// table senza isDeleted) ma diventano invisibili nelle query di lettura
  /// perché il JOIN filtra i bagagli con [isDeleted = false].
  Future<int> deleteLuggage(String id) {
    return (update(luggages)..where((l) => l.id.equals(id))).write(
      LuggagesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Ottiene i bagagli non eliminati associati a un viaggio tramite junction table.
  Future<List<Luggage>> getLuggagesByTrip(String tripId) async {
    final query =
        select(luggages).join([
          innerJoin(
            tripLuggageEntries,
            tripLuggageEntries.luggageId.equalsExp(luggages.id),
          ),
        ])..where(
          tripLuggageEntries.tripId.equals(tripId) &
              luggages.isDeleted.equals(false),
        );

    final results = await query.get();
    return results.map((row) => row.readTable(luggages)).toList();
  }

  /// Associa un bagaglio a un viaggio (inserisce entry nella junction table).
  Future<void> linkLuggageToTrip(String tripId, String luggageId) async {
    await into(tripLuggageEntries).insert(
      TripLuggageEntriesCompanion.insert(tripId: tripId, luggageId: luggageId),
    );
  }

  /// Rimuove l'associazione tra un bagaglio e un viaggio.
  Future<void> unlinkLuggageFromTrip(String tripId, String luggageId) async {
    await (delete(tripLuggageEntries)..where(
          (entry) =>
              entry.tripId.equals(tripId) & entry.luggageId.equals(luggageId),
        ))
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
      await (delete(
        tripLuggageEntries,
      )..where((entry) => entry.tripId.equals(tripId))).go();

      if (luggageIds.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            tripLuggageEntries,
            luggageIds
                .map(
                  (luggageId) => TripLuggageEntriesCompanion.insert(
                    tripId: tripId,
                    luggageId: luggageId,
                  ),
                )
                .toList(),
          );
        });
      }
    });
  }

  /// Conta il numero di bagagli non eliminati in una casa
  Future<int> countLuggagesByHouse(String houseId) async {
    final query = selectOnly(luggages)
      ..addColumns([luggages.id.count()])
      ..where(
        luggages.houseId.equals(houseId) & luggages.isDeleted.equals(false),
      );

    final result = await query.getSingleOrNull();
    return result?.read(luggages.id.count()) ?? 0;
  }
}
