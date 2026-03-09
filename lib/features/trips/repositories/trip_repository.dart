import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/trip_model.dart';
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
  );
}

abstract class TripRepository {
  Future<bool> init();
  Future<void> addTrip(TripModel model);
  Future<TripModel> getTripById(String id);
  Future<List<TripModel>> getAllTrips();
  Future<bool> deleteTrip(String id);
  Future<void> updateTrip(TripModel model);
}
