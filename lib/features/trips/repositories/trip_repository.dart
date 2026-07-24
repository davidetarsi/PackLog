import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/trip_model.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/services/persistence_services.dart';
import 'drift_trip_repository.dart';

part 'trip_repository.g.dart';

@Riverpod(keepAlive: true)
TripRepository tripRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return DriftTripRepository(
    database.tripsDao,
    database.luggagesDao,
    dbService,
    () => ref.read(currentUserIdProvider),
  );
}

abstract class TripRepository {
  Future<bool> init();
  Future<void> addTrip(TripModel model);
  Future<TripModel> getTripById(String id);
  Future<List<TripModel>> getAllTrips();
  Future<bool> deleteTrip(String id);
  Future<void> updateTrip(TripModel model);

  /// Aggiunge [items] a un viaggio esistente senza toccare gli item già
  /// presenti (operazione additiva, non sostitutiva come [updateTrip]).
  /// Idempotente: item già presenti nel viaggio vengono ignorati.
  Future<void> addItemsToTrip(String tripId, List<TripItem> items);

  Future<String> duplicateTrip(String tripId, {String nameSuffix = ' (Copia)'});

  /// Fast-path per il toggle della singola voce di checklist nel packing.
  /// Vedi [TripsDao.setTripItemChecked].
  Future<void> setTripItemChecked(String tripId, String itemId, bool isChecked);
}
