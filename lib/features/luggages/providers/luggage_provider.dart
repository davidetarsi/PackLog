import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/luggage_model.dart';
import '../repositories/luggage_repository.dart';

part 'luggage_provider.g.dart';

/// Notifier globale per tutti i bagagli dell'app.
/// 
/// Gestisce CRUD operations con state caching e invalidation automatica.
@Riverpod(keepAlive: true)
class LuggageNotifier extends _$LuggageNotifier {
  LuggageRepository? repository;

  @override
  Future<List<LuggageModel>> build() async {
    repository = ref.watch(luggageRepositoryProvider);
    final luggages = await repository!.getAllLuggages();
    return luggages;
  }

  Future<void> addLuggage(LuggageModel model) async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addLuggage(model);
      final luggages = await repository!.getAllLuggages();
      state = AsyncData(luggages);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateLuggage(LuggageModel model) async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateLuggage(model);
      final luggages = await repository!.getAllLuggages();
      state = AsyncData(luggages);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteLuggage(String id) async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteLuggage(id);
      final luggages = await repository!.getAllLuggages();
      state = AsyncData(luggages);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      final luggages = await repository!.getAllLuggages();
      state = AsyncData(luggages);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

/// Family provider per ottenere i bagagli di una casa specifica.
/// 
/// Filtra i bagagli in base all'houseId e li mantiene in cache.
@riverpod
Future<List<LuggageModel>> luggagesByHouse(LuggagesByHouseRef ref, String houseId) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.getLuggagesByHouseId(houseId);
}

/// Family provider per ottenere i bagagli di un viaggio.
/// 
/// Usa la junction table per caricare solo i bagagli associati.
@riverpod
Future<List<LuggageModel>> luggagesByTrip(LuggagesByTripRef ref, String tripId) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.getLuggagesByTripId(tripId);
}

/// Provider per contare i bagagli di una casa.
@riverpod
Future<int> luggageCountByHouse(LuggageCountByHouseRef ref, String houseId) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.countLuggagesByHouse(houseId);
}
