import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';

class LocalTripRepository implements TripRepository {
  final SharedPreferences _sharedPreferences;
  static const String _tripsKey = 'trips';

  LocalTripRepository(this._sharedPreferences);

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> addTrip(TripModel model) async {
    final trips = await getAllTrips();
    final updatedTrips = [...trips, model];
    await _saveTrips(updatedTrips);
  }

  @override
  Future<TripModel> getTripById(String id) async {
    final trips = await getAllTrips();
    return trips.firstWhere((trip) => trip.id == id);
  }

  @override
  Future<List<TripModel>> getAllTrips() async {
    final tripsJson = _sharedPreferences.getStringList(_tripsKey) ?? [];
    return tripsJson
        .map((json) => TripModel.fromJson(jsonDecode(json)))
        .toList();
  }

  @override
  Future<bool> deleteTrip(String id) async {
    final trips = await getAllTrips();
    trips.removeWhere((trip) => trip.id == id);
    await _saveTrips(trips);
    return true;
  }

  @override
  Future<void> updateTrip(TripModel model) async {
    final trips = await getAllTrips();
    final index = trips.indexWhere((t) => t.id == model.id);
    if (index != -1) {
      final updatedTrip = model.copyWith(updatedAt: DateTime.now());
      trips[index] = updatedTrip;
      await _saveTrips(trips);
    }
  }

  Future<void> _saveTrips(List<TripModel> trips) async {
    final tripsJson = trips.map((t) => jsonEncode(t.toJson())).toList();
    await _sharedPreferences.setStringList(_tripsKey, tripsJson);
  }
}

