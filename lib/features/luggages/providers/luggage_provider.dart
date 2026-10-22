import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/database/exceptions/database_exceptions.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../model/luggage_model.dart';
import '../repositories/luggage_repository.dart';
import '../../trips/providers/trip_provider.dart';

part 'luggage_provider.g.dart';

/// Unica lista dei bagagli dell’utente, indipendente dalle case.
@Riverpod(keepAlive: true)
class LuggageNotifier extends _$LuggageNotifier
    with SyncedCrudNotifier<LuggageModel> {
  LuggageRepository get _repo => ref.read(luggageRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  @override
  Future<List<LuggageModel>> build() {
    ref.watch(syncTriggerProvider);
    return ref.watch(luggageRepositoryProvider).getAllLuggages();
  }

  @override
  void onMutationSuccess(List<LuggageModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
    // Nome e soft-delete devono riflettersi anche nei viaggi già in cache.
    if (ref.exists(tripNotifierProvider)) {
      ref.invalidate(tripNotifierProvider);
    }
    ref.invalidate(luggagesByTripProvider);
  }

  Future<void> addLuggage(LuggageModel model) => mutate(
    operation: () => _repo.addLuggage(model),
    committedState: (previous) => [
      ...previous.where((l) => l.id != model.id),
      model,
    ],
    reload: () => _repo.getAllLuggages(),
    rethrowOnly: true,
    onSuccess: (_) => _analytics.trackLuggageCreated(size: model.sizeType.name),
  );

  Future<void> updateLuggage(LuggageModel model) => mutate(
    operation: () => _repo.updateLuggage(model),
    committedState: (previous) => [
      for (final l in previous) l.id == model.id ? model : l,
    ],
    reload: () => _repo.getAllLuggages(),
    rethrowOnly: true,
  );

  Future<void> deleteLuggage(String id) => mutate(
    operation: () async {
      if (!await _repo.deleteLuggage(id)) {
        throw EntitySaveException('deleteLuggage($id)');
      }
    },
    committedState: (previous) => previous.where((l) => l.id != id).toList(),
    reload: () => _repo.getAllLuggages(),
    rethrowOnly: true,
  );

  Future<void> refresh() => mutate(
    operation: () async {},
    reload: () => _repo.getAllLuggages(),
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );
}

/// Family provider per ottenere i bagagli di un viaggio.
///
/// Usa la junction table per caricare solo i bagagli associati.
@riverpod
Future<List<LuggageModel>> luggagesByTrip(Ref ref, String tripId) async {
  final repository = ref.watch(luggageRepositoryProvider);
  return repository.getLuggagesByTripId(tripId);
}
