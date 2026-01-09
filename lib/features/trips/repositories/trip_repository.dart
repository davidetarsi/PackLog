import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/trip_model.dart';
import '../repositories/local_trip_repository.dart';

part 'trip_repository.g.dart';

@Riverpod(keepAlive: true)
Future<TripRepository> tripRepository(Ref ref) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final repository = LocalTripRepository(sharedPreferences);
  await repository.init();
  return repository;
}

abstract class TripRepository {
  Future<bool> init();
  Future<void> addTrip(TripModel model);
  Future<TripModel> getTripById(String id);
  Future<List<TripModel>> getAllTrips();
  Future<bool> deleteTrip(String id);
  Future<void> updateTrip(TripModel model);
}

