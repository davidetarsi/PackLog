import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../model/luggage_model.dart';
import '../repositories/luggage_repository.dart';

part 'luggage_provider.g.dart';

/// Notifier family per i bagagli di una specifica casa.
///
/// Pattern allineato a [ItemNotifier]: una sola sorgente di verità per
/// casa, le mutazioni ricaricano la lista filtrata e si propagano
/// automaticamente ai consumer senza bisogno di `ref.invalidate` manuali.
@Riverpod(keepAlive: true)
class LuggageNotifier extends _$LuggageNotifier {
  LuggageRepository? repository;

  @override
  Future<List<LuggageModel>> build(String houseId) async {
    repository = ref.watch(luggageRepositoryProvider);
    return repository!.getLuggagesByHouseId(houseId);
  }

  Future<void> addLuggage(LuggageModel model) async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.addLuggage(model);
      final luggages = await repository!.getLuggagesByHouseId(houseId);
      state = AsyncData(luggages);
      ref
          .read(coreAnalyticsServiceProvider)
          .trackLuggageCreated(size: model.sizeType.name);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateLuggage(LuggageModel model) async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.updateLuggage(model);
      final luggages = await repository!.getLuggagesByHouseId(houseId);
      state = AsyncData(luggages);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteLuggage(String id) async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository!.deleteLuggage(id);
      final luggages = await repository!.getLuggagesByHouseId(houseId);
      state = AsyncData(luggages);
      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refresh() async {
    repository ??= ref.read(luggageRepositoryProvider);
    state = const AsyncLoading();
    try {
      final luggages = await repository!.getLuggagesByHouseId(houseId);
      state = AsyncData(luggages);
    } catch (error, stackTrace) {
      // No rethrow: refresh() is wired to ErrorState.onRetry (VoidCallback).
      state = AsyncError(error, stackTrace);
    }
  }
}

// Nota: l'ex [luggagesByHouseProvider] è stato eliminato — la stessa funzione
// è ora servita da [luggageNotifierProvider] con la signature family
// `(String houseId)`. Eliminato anche il bisogno di
// `ref.invalidate(luggageNotifierProvider(...))` dopo le mutazioni.

/// Lista globale di tutti i bagagli (cross-casa). Usata dal selector
/// nel form di creazione viaggio, dove l'utente può scegliere bagagli
/// da qualunque casa.
@Riverpod(keepAlive: true)
Future<List<LuggageModel>> allLuggages(Ref ref) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.getAllLuggages();
}

/// Family provider per ottenere i bagagli di un viaggio.
///
/// Usa la junction table per caricare solo i bagagli associati.
@riverpod
Future<List<LuggageModel>> luggagesByTrip(Ref ref, String tripId) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.getLuggagesByTripId(tripId);
}

/// Provider per contare i bagagli di una casa.
@riverpod
Future<int> luggageCountByHouse(Ref ref, String houseId) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.countLuggagesByHouse(houseId);
}
