import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/trips_table.dart';
import '../tables/trip_items_table.dart';
import '../tables/luggages_table.dart';
import '../tables/trip_luggage_entries_table.dart';

part 'trips_dao.g.dart';

/// DAO per le operazioni CRUD sui viaggi e i loro oggetti.
@DriftAccessor(tables: [Trips, TripItemEntries, Luggages, TripLuggageEntries])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  // === TRIPS ===

  /// Ottiene tutti i viaggi non eliminati
  Future<List<Trip>> getAllTrips() =>
      (select(trips)..where((t) => t.isDeleted.equals(false))).get();

  /// Ottiene tutti i viaggi non eliminati come stream
  Stream<List<Trip>> watchAllTrips() =>
      (select(trips)..where((t) => t.isDeleted.equals(false))).watch();

  /// Ottiene un viaggio per ID (solo se non eliminato)
  Future<Trip?> getTripById(String id) {
    return (select(trips)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserisce un nuovo viaggio
  Future<int> insertTrip(TripsCompanion trip) {
    return into(trips).insert(trip);
  }

  /// Aggiorna un viaggio esistente
  Future<bool> updateTrip(TripsCompanion trip) {
    return update(trips).replace(trip);
  }

  /// Soft-delete di un viaggio con cleanup fisico dei dati snapshot.
  ///
  /// - Elimina fisicamente [TripItemEntries]: sono dati snapshot legati al
  ///   viaggio, senza necessità di storico per la sincronizzazione cloud.
  /// - Elimina fisicamente [TripLuggageEntries]: junction table senza isDeleted.
  /// - Imposta [isDeleted = true] sul viaggio stesso.
  Future<int> deleteTrip(String id) async {
    return transaction(() async {
      // Cleanup fisico dei dati snapshot/junction (non hanno isDeleted)
      await (delete(tripItemEntries)
            ..where((ti) => ti.tripId.equals(id)))
          .go();
      await (delete(tripLuggageEntries)
            ..where((tle) => tle.tripId.equals(id)))
          .go();

      return (update(trips)..where((t) => t.id.equals(id))).write(
        TripsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
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
    return (select(tripItemEntries)
          ..where((ti) => ti.tripId.equals(tripId)))
        .get();
  }

  /// Ottiene gli oggetti di un viaggio come stream
  Stream<List<TripItemEntry>> watchTripItemsByTripId(String tripId) {
    return (select(tripItemEntries)
          ..where((ti) => ti.tripId.equals(tripId)))
        .watch();
  }

  /// Inserisce un oggetto nel viaggio
  Future<int> insertTripItem(TripItemEntriesCompanion tripItem) {
    return into(tripItemEntries).insert(tripItem);
  }

  /// Aggiorna un oggetto del viaggio
  Future<bool> updateTripItem(TripItemEntriesCompanion tripItem) {
    return update(tripItemEntries).replace(tripItem);
  }

  /// Elimina fisicamente un oggetto dal viaggio (dato snapshot, nessun isDeleted)
  Future<int> deleteTripItem(String id) {
    return (delete(tripItemEntries)..where((ti) => ti.id.equals(id))).go();
  }

  /// Elimina fisicamente tutti gli oggetti di un viaggio
  Future<int> deleteTripItemsByTripId(String tripId) {
    return (delete(tripItemEntries)
          ..where((ti) => ti.tripId.equals(tripId)))
        .go();
  }

  /// Inserisce multiple oggetti viaggio (per migrazione)
  Future<void> insertMultipleTripItems(
    List<TripItemEntriesCompanion> items,
  ) async {
    await batch((batch) {
      batch.insertAll(tripItemEntries, items);
    });
  }

  /// Sostituisce tutti gli oggetti di un viaggio
  Future<void> replaceTripItems(
    String tripId,
    List<TripItemEntriesCompanion> items,
  ) async {
    await transaction(() async {
      await deleteTripItemsByTripId(tripId);
      if (items.isNotEmpty) {
        await insertMultipleTripItems(items);
      }
    });
  }

  /// Duplica un viaggio con tutti i suoi oggetti (Deep Copy con transazione atomica)
  ///
  /// Crea un nuovo viaggio con:
  /// - Nuovo UUID
  /// - Nome: "$originalName (Copia)"
  /// - Tutti gli oggetti copiati (preservando nome, categoria, quantità)
  ///
  /// Returns: ID del nuovo viaggio creato
  /// Throws: Exception se il viaggio originale non esiste o è stato eliminato
  Future<String> duplicateTrip(String originalTripId, String newTripId) async {
    return transaction(() async {
      final originalTrip = await getTripById(originalTripId);
      if (originalTrip == null) {
        throw Exception('Trip $originalTripId not found');
      }

      final now = DateTime.now();
      final newTrip = TripsCompanion.insert(
        id: newTripId,
        name: '${originalTrip.name} (Copia)',
        description: Value(originalTrip.description),
        departureDateTime: Value(originalTrip.departureDateTime),
        returnDateTime: Value(originalTrip.returnDateTime),
        destinationHouseId: Value(originalTrip.destinationHouseId),
        locationPlaceId: Value(originalTrip.locationPlaceId),
        locationDisplayName: Value(originalTrip.locationDisplayName),
        locationName: Value(originalTrip.locationName),
        locationCity: Value(originalTrip.locationCity),
        locationState: Value(originalTrip.locationState),
        locationCountry: Value(originalTrip.locationCountry),
        locationType: Value(originalTrip.locationType),
        locationLat: Value(originalTrip.locationLat),
        locationLon: Value(originalTrip.locationLon),
        isSaved: Value(originalTrip.isSaved),
        createdAt: now,
        updatedAt: now,
      );
      await insertTrip(newTrip);

      final originalItems = await getTripItemsByTripId(originalTripId);
      if (originalItems.isNotEmpty) {
        final copiedItems = originalItems.map((item) {
          return TripItemEntriesCompanion.insert(
            id: item.id,
            tripId: newTripId,
            name: item.name,
            category: item.category,
            quantity: Value(item.quantity),
            originHouseId: Value(item.originHouseId),
            isChecked: const Value(false),
          );
        }).toList();

        await insertMultipleTripItems(copiedItems);
      }

      return newTripId;
    });
  }

  // === OPTIMIZED BATCH LOADING (Avoid N+1) ===

  /// Ottiene tutti i trip items per tutti i viaggi in una singola query.
  ///
  /// La selezione per [isDeleted] viene gestita a monte dal filtro su [getAllTrips]:
  /// i trip items vengono abbinati in memoria solo ai trip non eliminati.
  ///
  /// Returns: `Map` con tripId come chiave e `List<TripItemEntry>` come valore.
  Future<Map<String, List<TripItemEntry>>> getAllTripItemsGrouped() async {
    final allTripItems = await select(tripItemEntries).get();

    final Map<String, List<TripItemEntry>> grouped = {};
    for (final item in allTripItems) {
      grouped.putIfAbsent(item.tripId, () => []).add(item);
    }

    return grouped;
  }

  /// Ottiene tutti i bagagli non eliminati associati a viaggi, raggruppati per trip_id.
  ///
  /// Filtra i bagagli con [isDeleted = false] a livello SQL per escludere
  /// bagagli soft-deleted dalle associazioni di viaggio.
  ///
  /// Returns: `Map` con tripId come chiave e `List<Luggage>` come valore.
  Future<Map<String, List<Luggage>>> getAllTripLuggagesGrouped() async {
    final query = select(luggages).join([
      innerJoin(
        tripLuggageEntries,
        tripLuggageEntries.luggageId.equalsExp(luggages.id),
      ),
    ])..where(luggages.isDeleted.equals(false));

    final results = await query.get();

    final Map<String, List<Luggage>> grouped = {};
    for (final row in results) {
      final luggage = row.readTable(luggages);
      final tripId = row.readTable(tripLuggageEntries).tripId;
      grouped.putIfAbsent(tripId, () => []).add(luggage);
    }

    return grouped;
  }

  /// Ottiene un viaggio non eliminato con tutti i suoi dati in un'unica chiamata.
  ///
  /// Performance: 3 queries parallele invece di 1 + N per items + M per luggages.
  Future<TripWithRelations?> getTripByIdWithRelations(String id) async {
    final trip = await getTripById(id);
    if (trip == null) return null;

    final results = await Future.wait([
      getTripItemsByTripId(id),
      db.luggagesDao.getLuggagesByTrip(id),
    ]);

    return TripWithRelations(
      trip: trip,
      items: results[0] as List<TripItemEntry>,
      luggages: results[1] as List<Luggage>,
    );
  }
}

/// Classe di supporto per raggruppare dati relazionali di un trip.
///
/// Usato dal DAO per restituire trip + items + luggages in un'unica struttura.
class TripWithRelations {
  final Trip trip;
  final List<TripItemEntry> items;
  final List<Luggage> luggages;

  TripWithRelations({
    required this.trip,
    required this.items,
    required this.luggages,
  });
}
