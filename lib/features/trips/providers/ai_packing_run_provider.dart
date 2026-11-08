import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/core_analytics_service.dart';
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
import '../services/suitcase_analytics.dart';
import 'trip_provider.dart';
import 'trip_weather_provider.dart';

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
    // Un tentativo: dalla partenza (o dal salvataggio, se la risposta c'era
    // già) fino all'esito.
    final timer = Stopwatch()..start();
    var result = _pending;
    final retrySave = result != null;
    if (result == null) {
      try {
        result = await _service.generate(
          request.job.body,
          houseId: request.job.houseId,
        );
      } catch (error, stack) {
        if (_stale(generation)) return;
        ref.invalidate(gptUsageProvider);
        // Offline (e quindi il timeout) e casi previsti (crediti, armadio)
        // non sono guasti da segnalare.
        if (error is PackTripException && error is! PackTripNetworkException) {
          ref
              .read(monitoringServiceProvider)
              .captureException(error, stackTrace: stack);
        }
        _trackFinished(request, packOutcomeOf(error), timer);
        state = AiRunFailed(request, error);
        return;
      }
      if (_stale(generation)) return;
      ref.invalidate(gptUsageProvider);
      unawaited(PackTripTiming.record(timer.elapsed));
    }

    final TripModel? saved;
    try {
      saved = await _adopt(request, result, generation);
    } catch (error, stack) {
      if (_stale(generation)) return;
      // Un errore silenzioso per l'utente: la risposta è arrivata e il
      // credito è speso, ma la valigia non si è salvata.
      ref
          .read(monitoringServiceProvider)
          .captureException(error, stackTrace: stack);
      _trackFinished(
        request,
        'save_failed',
        timer,
        result: result,
        retrySave: retrySave,
      );
      _pending = result;
      state = AiRunFailed(request, error, saveOnly: true);
      return;
    }
    if (saved == null) return;
    // Il viaggio è salvato: da qui un errore non lo cancella.
    _trackFinished(request, 'ok', timer, result: result, retrySave: retrySave);
    await _afterSave(saved);
    if (_stale(generation)) return;
    state = AiRunDone(saved.id, itemsError: _itemsError);
  }

  bool _itemsError = false;

  /// Salva la valigia. Ritorna il viaggio salvato; null se il lavoro è
  /// stato scartato (viaggio sparito, [clear]).
  Future<TripModel?> _adopt(
    AiPackingRequest request,
    AiPackingResult proposal,
    int generation,
  ) async {
    // Il viaggio si legge ora: nel frattempo può essere cambiato o sparito.
    final trips = await ref.read(tripNotifierProvider.future);
    if (_stale(generation)) return null;
    final TripModel? base;
    if (request.isNew) {
      base = request.trip;
    } else {
      base = trips.where((t) => t.id == request.trip.id).firstOrNull;
    }
    if (base == null) {
      // Viaggio cancellato durante la richiesta: niente da salvare.
      clear();
      return null;
    }

    List<ItemModel>? houseItems;
    try {
      houseItems = await ref.read(
        itemNotifierProvider(proposal.houseId).future,
      );
    } catch (e) {
      debugPrint('[AiPackingRun] oggetti della casa non leggibili: $e');
    }
    if (_stale(generation)) return null;

    final adopted = adoptedTrip(
      trip: base,
      proposal: proposal,
      setup: request.setup,
      luggage: request.luggage,
      houseItems: houseItems,
    );
    final notifier = ref.read(tripNotifierProvider.notifier);
    // Un viaggio nuovo con quell'id può esserci già (un Riprova dopo un
    // salvataggio riuscito a metà): si aggiorna, mai un secondo `addTrip`.
    final exists = trips.any((t) => t.id == adopted.id);
    if (request.isNew && !exists) {
      await notifier.addTrip(adopted, source: request.tripSource ?? 'new');
    } else {
      await notifier.updateTrip(adopted);
    }
    _pending = null;
    _itemsError = houseItems == null;
    return adopted;
  }

  /// `ai_suitcase_finished`, una volta per tentativo. Con [retrySave] è il
  /// solo salvataggio rifatto (`retry_save`): la generazione ha già il suo
  /// evento. Armadio e meteo si leggono solo se già caricati: qui non si
  /// avviano richieste. Un errore dell'analytics non ferma il lavoro.
  void _trackFinished(
    AiPackingRequest request,
    String outcome,
    Stopwatch timer, {
    AiPackingResult? result,
    bool retrySave = false,
  }) {
    try {
      timer.stop();
      final analytics = ref.read(coreAnalyticsServiceProvider);
      if (outcome == 'credits') {
        analytics.trackAiLimitReached(feature: 'suitcase');
      }

      final job = request.job;
      final trip = request.trip.copyWith(aiSetup: request.setup);
      final itemsProvider = itemNotifierProvider(job.houseId);
      final items = ref.exists(itemsProvider)
          ? ref.read(itemsProvider).valueOrNull
          : null;
      final weatherProvider = tripWeatherNotifierProvider(trip.id);
      final weatherState = ref.exists(weatherProvider)
          ? ref.read(weatherProvider).valueOrNull
          : null;
      final days = daysToDeparture(trip.departureDateTime, DateTime.now());
      analytics.trackAiSuitcaseFinished(
        outcome: outcome,
        durationMs: timer.elapsedMilliseconds,
        tripId: trip.id,
        properties: {
          'nights': job.nights,
          'stops': request.setup.stops.length,
          'is_regeneration': job.isRegeneration,
          'setup_changed': job.setupChanged,
          'left_wait': !_attached,
          if (retrySave) 'retry_save': true,
          'days_to_departure': ?days,
          if (result != null) 'proposal_items': result.proposal.length,
          if (result != null) 'slots_count': result.slots?.length ?? 0,
          ...wardrobeStats(items ?? const []),
          ...tripContext(
            trip,
            luggage: request.luggage,
            weather: weatherState is TripWeatherReady
                ? weatherState.weather
                : null,
          ),
        },
      );
    } catch (e) {
      debugPrint('[AiPackingRun] ai_suitcase_finished: $e');
    }
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
    final analytics = ref.read(coreAnalyticsServiceProvider);
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
