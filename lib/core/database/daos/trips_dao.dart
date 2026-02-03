import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/trips_table.dart';
import '../tables/trip_items_table.dart';

part 'trips_dao.g.dart';

/// DAO per le operazioni CRUD sui viaggi e i loro oggetti.
@DriftAccessor(tables: [Trips, TripItemEntries])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  // === TRIPS ===

  /// Ottiene tutti i viaggi
  Future<List<Trip>> getAllTrips() => select(trips).get();

  /// Ottiene tutti i viaggi come stream
  Stream<List<Trip>> watchAllTrips() => select(trips).watch();

  /// Ottiene un viaggio per ID
  Future<Trip?> getTripById(String id) {
    return (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Inserisce un nuovo viaggio
  Future<int> insertTrip(TripsCompanion trip) {
    return into(trips).insert(trip);
  }

  /// Aggiorna un viaggio esistente
  Future<bool> updateTrip(TripsCompanion trip) {
    return update(trips).replace(trip);
  }

  /// Elimina un viaggio per ID (cascade elimina anche trip_items)
  Future<int> deleteTrip(String id) {
    return (delete(trips)..where((t) => t.id.equals(id))).go();
  }

  /// Inserisce multiple viaggi (per migrazione)
  Future<void> insertMultipleTrips(List<TripsCompanion> tripsList) async {
    await batch((batch) {
      batch.insertAll(trips, tripsList);
    });
  }

  // === TRIP ITEMS ===

  /// Ottiene tutti gli oggetti di un viaggio
  Future<List<TripItemEntry>> getTripItemsByTripId(String tripId) {
    return (select(tripItemEntries)..where((ti) => ti.tripId.equals(tripId))).get();
  }

  /// Ottiene gli oggetti di un viaggio come stream
  Stream<List<TripItemEntry>> watchTripItemsByTripId(String tripId) {
    return (select(tripItemEntries)..where((ti) => ti.tripId.equals(tripId))).watch();
  }

  /// Inserisce un oggetto nel viaggio
  Future<int> insertTripItem(TripItemEntriesCompanion tripItem) {
    return into(tripItemEntries).insert(tripItem);
  }

  /// Aggiorna un oggetto del viaggio
  Future<bool> updateTripItem(TripItemEntriesCompanion tripItem) {
    return update(tripItemEntries).replace(tripItem);
  }

  /// Elimina un oggetto dal viaggio
  Future<int> deleteTripItem(String id) {
    return (delete(tripItemEntries)..where((ti) => ti.id.equals(id))).go();
  }

  /// Elimina tutti gli oggetti di un viaggio
  Future<int> deleteTripItemsByTripId(String tripId) {
    return (delete(tripItemEntries)..where((ti) => ti.tripId.equals(tripId))).go();
  }

  /// Inserisce multiple oggetti viaggio (per migrazione)
  Future<void> insertMultipleTripItems(List<TripItemEntriesCompanion> items) async {
    await batch((batch) {
      batch.insertAll(tripItemEntries, items);
    });
  }

  /// Sostituisce tutti gli oggetti di un viaggio
  Future<void> replaceTripItems(String tripId, List<TripItemEntriesCompanion> items) async {
    await transaction(() async {
      await deleteTripItemsByTripId(tripId);
      if (items.isNotEmpty) {
        await insertMultipleTripItems(items);
      }
    });
  }
}
