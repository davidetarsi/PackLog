import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';

part 'trip_provider.g.dart';

@Riverpod(keepAlive: true)
class TripNotifier extends _$TripNotifier {
  TripRepository? repository;

  @override
  Future<List<TripModel>> build() async {
    repository ??= await ref.watch(tripRepositoryProvider.future);
    final trips = await repository!.getAllTrips();
    return trips;
  }

  Future<void> addTrip(TripModel model) async {
    repository ??= await ref.read(tripRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      await repository!.addTrip(model);
      final trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateTrip(TripModel model) async {
    repository ??= await ref.read(tripRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      await repository!.updateTrip(model);
      final trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteTrip(String id) async {
    repository ??= await ref.read(tripRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      await repository!.deleteTrip(id);
      final trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> toggleItemCheck(String tripId, String itemId) async {
    repository ??= await ref.read(tripRepositoryProvider.future);
    try {
      final trips = state.value;
      if (trips == null) return;

      final tripIndex = trips.indexWhere((t) => t.id == tripId);
      if (tripIndex == -1) return;

      final trip = trips[tripIndex];
      final itemIndex = trip.items.indexWhere((i) => i.id == itemId);
      if (itemIndex == -1) return;

      final updatedItems = [...trip.items];
      updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
        isChecked: !updatedItems[itemIndex].isChecked,
      );

      final updatedTrip = trip.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      await repository!.updateTrip(updatedTrip);
      final newTrips = await repository!.getAllTrips();
      state = AsyncData(newTrips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    repository ??= await ref.read(tripRepositoryProvider.future);
    state = const AsyncLoading();
    try {
      final trips = await repository!.getAllTrips();
      state = AsyncData(trips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Toggle dello stato salvato/preferito di un viaggio
  Future<void> toggleSaved(String tripId) async {
    repository ??= await ref.read(tripRepositoryProvider.future);
    try {
      final trips = state.value;
      if (trips == null) return;

      final tripIndex = trips.indexWhere((t) => t.id == tripId);
      if (tripIndex == -1) return;

      final trip = trips[tripIndex];
      final updatedTrip = trip.copyWith(
        isSaved: !trip.isSaved,
        updatedAt: DateTime.now(),
      );

      await repository!.updateTrip(updatedTrip);
      final newTrips = await repository!.getAllTrips();
      state = AsyncData(newTrips);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

