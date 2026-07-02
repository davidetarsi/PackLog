import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/luggage_model.dart';
import '../repositories/luggage_repository.dart';

part 'luggage_provider.g.dart';

/// Notifier family per i bagagli di una specifica casa.
///
/// Pattern allineato a [ItemNotifier]: una sola sorgente di verità per
/// casa, le mutazioni ricaricano la lista filtrata e si propagano
/// automaticamente ai consumer senza bisogno di `ref.invalidate` manuali.
@Riverpod(keepAlive: true)
class LuggageNotifier extends _$LuggageNotifier
    with SyncedCrudNotifier<LuggageModel> {
  LuggageRepository get _repo => ref.read(luggageRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  @override
  Future<List<LuggageModel>> build(String houseId) =>
      _repo.getLuggagesByHouseId(houseId);

  @override
  void onMutationSuccess(List<LuggageModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
  }

  Future<void> addLuggage(LuggageModel model) => mutate(
    operation: () => _repo.addLuggage(model),
    reload: () => _repo.getLuggagesByHouseId(houseId),
    rethrowOnly: true,
    onSuccess: (_) => _analytics.trackLuggageCreated(size: model.sizeType.name),
  );

  Future<void> updateLuggage(LuggageModel model) => mutate(
    operation: () => _repo.updateLuggage(model),
    reload: () => _repo.getLuggagesByHouseId(houseId),
    rethrowOnly: true,
  );

  Future<void> deleteLuggage(String id) => mutate(
    operation: () => _repo.deleteLuggage(id),
    reload: () => _repo.getLuggagesByHouseId(houseId),
    rethrowOnly: true,
  );

  Future<void> refresh() => mutate(
    operation: () async {},
    reload: () => _repo.getLuggagesByHouseId(houseId),
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );
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
