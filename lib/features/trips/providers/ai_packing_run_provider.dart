import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../profile/providers/gpt_usage_provider.dart';
import '../../tour/model/onboarding_state.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import '../model/ai_packing.dart';
import '../model/ai_packing_request.dart';
import '../model/trip_model.dart';
import '../services/ai_suitcase_adoption.dart';
import '../services/pack_trip_service.dart';
import '../services/pack_trip_timing.dart';
import 'trip_provider.dart';

part 'ai_packing_run_provider.g.dart';

/// Stato del lavoro che prepara la valigia AI.
sealed class AiPackingRunState {
  const AiPackingRunState();
}

/// Nessun lavoro.
class AiRunIdle extends AiPackingRunState {
  const AiRunIdle();
}

/// `pack-trip` sta lavorando (o il salvataggio è in corso).
class AiRunRunning extends AiPackingRunState {
  const AiRunRunning(this.request);
  final AiPackingRequest request;
}

/// Il lavoro è fallito: [request] serve a riprovare.
class AiRunFailed extends AiPackingRunState {
  const AiRunFailed(this.request, this.error, {this.saveOnly = false});
  final AiPackingRequest request;
  final Object error;

  /// La risposta di `pack-trip` era già arrivata (credito consumato) e a
  /// fallire è stato solo il salvataggio: [AiPackingRun.retry] rifà solo
  /// quello, senza chiamare di nuovo il server.
  final bool saveOnly;

  bool get canRetrySaveOnly => saveOnly;
}

/// La valigia è arrivata ed è salvata sul viaggio [tripId]. [itemsError]: gli
/// oggetti della casa non si leggevano, salvata la sola proposta.
class AiRunDone extends AiPackingRunState {
  const AiRunDone(this.tripId, {required this.itemsError});
  final String tripId;
  final bool itemsError;
}

/// Il lavoro AI vive qui e non nelle pagine: chiamata a `pack-trip`, tempi,
/// monitoraggio, salvataggio della valigia ed eventi. Dopo [AiRunDone] chi
/// ha finito di mostrarlo chiama [clear]: il provider non si azzera da solo.
@Riverpod(keepAlive: true)
class AiPackingRun extends _$AiPackingRun {
  late PackTripService _service;
  bool _attached = false;

  /// Numero del lavoro corrente: un [clear] o un nuovo [start] lo cambiano e
  /// il lavoro vecchio, quando arriva, non scrive niente.
  int _generation = 0;

  /// La risposta già arrivata, se il salvataggio è fallito: [retry] la
  /// riprova senza chiamare di nuovo `pack-trip` (che consuma un credito).
  AiPackingResult? _pending;

  @override
  AiPackingRunState build() {
    _service = ref.watch(packTripServiceProvider);
    return const AiRunIdle();
  }

  /// C'è una pagina d'attesa che mostra il lavoro.
  bool get attached => _attached;
  void attach() => _attached = true;
  void detach() => _attached = false;

  /// Avvia il lavoro. False se ce n'è già uno in corso.
  bool start(AiPackingRequest request) {
    if (state is AiRunRunning) return false;
    _pending = null;
    _begin(request);
    return true;
  }

  /// Riprova dopo un errore.
  Future<void> retry() async {
    final current = state;
    if (current is! AiRunFailed) return;
    return _begin(current.request);
  }

  /// Torna a riposo; un lavoro ancora in corso viene scartato.
  void clear() {
    _generation++;
    _pending = null;
    state = const AiRunIdle();
  }

  Future<void> _begin(AiPackingRequest request) {
    final generation = ++_generation;
    state = AiRunRunning(request);
    return _run(request, generation);
  }

  bool _stale(int generation) => generation != _generation;

  Future<void> _run(AiPackingRequest request, int generation) async {
    var result = _pending;
    if (result == null) {
      final timer = Stopwatch()..start();
      try {
        result = await _service.generate(
          request.job.body,
          houseId: request.job.houseId,
        );
      } catch (error, stack) {
        if (_stale(generation)) return;
        ref.invalidate(gptUsageProvider);
        // Offline e casi previsti (crediti, armadio) non sono guasti da segnalare.
        if (error is PackTripException && error is! PackTripNetworkException) {
          ref
              .read(monitoringServiceProvider)
              .captureException(error, stackTrace: stack);
        }
        state = AiRunFailed(request, error);
        return;
      }
      if (_stale(generation)) return;
      ref.invalidate(gptUsageProvider);
      unawaited(PackTripTiming.record(timer.elapsed));
    }

    try {
      await _adopt(request, result, generation);
    } catch (error) {
      if (_stale(generation)) return;
      _pending = result;
      state = AiRunFailed(request, error, saveOnly: true);
    }
  }

  Future<void> _adopt(
    AiPackingRequest request,
    AiPackingResult proposal,
    int generation,
  ) async {
    // Il viaggio si legge ora: nel frattempo può essere cambiato o sparito.
    final trips = await ref.read(tripNotifierProvider.future);
    if (_stale(generation)) return;
    final TripModel? base;
    if (request.isNew) {
      base = request.trip;
    } else {
      base = trips.where((t) => t.id == request.trip.id).firstOrNull;
    }
    if (base == null) {
      // Viaggio cancellato durante la richiesta: niente da salvare.
      clear();
      return;
    }

    List<ItemModel>? houseItems;
    try {
      houseItems = await ref.read(
        itemNotifierProvider(proposal.houseId).future,
      );
    } catch (e) {
      debugPrint('[AiPackingRun] oggetti della casa non leggibili: $e');
    }
    if (_stale(generation)) return;

    final adopted = adoptedTrip(
      trip: base,
      proposal: proposal,
      setup: request.setup,
      luggage: request.luggage,
      houseItems: houseItems,
    );
    final notifier = ref.read(tripNotifierProvider.notifier);
    if (request.isNew) {
      await notifier.addTrip(adopted);
    } else {
      await notifier.updateTrip(adopted);
    }
    _pending = null;
    if (_stale(generation)) return;

    // Il viaggio è salvato: da qui un errore non lo cancella.
    await _afterSave(adopted);
    if (_stale(generation)) return;
    state = AiRunDone(adopted.id, itemsError: houseItems == null);
  }

  /// La prima valigia è fatta ("Dove vai?" si chiude) ed escono gli eventi.
  Future<void> _afterSave(TripModel saved) async {
    final result = saved.aiResult!;
    var fromFirstRun = false;
    try {
      final onboarding = ref.read(postLoginOnboardingProvider.notifier);
      fromFirstRun =
          (await ref.read(postLoginOnboardingProvider.future)).step ==
          OnboardingStep.firstTrip;
      await onboarding.completeFirstTrip();
    } catch (e) {
      debugPrint('[AiPackingRun] completeFirstTrip: $e');
    }
    final analytics = ref.read(analyticsServiceProvider);
    try {
      if (result.hasSlots) {
        await logFirstSuitcase(
          analytics,
          result,
          saved.items.length,
          fromFirstRun: fromFirstRun,
        );
      }
      logKitAutoAdded(analytics, result);
    } catch (e) {
      debugPrint('[AiPackingRun] eventi: $e');
    }
  }
}
