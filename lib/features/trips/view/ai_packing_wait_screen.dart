import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../items/providers/item_provider.dart';
import '../../profile/providers/gpt_usage_provider.dart';
import '../model/ai_packing.dart';
import '../model/pack_trip_job.dart';
import '../providers/trip_provider.dart';
import '../providers/trip_weather_provider.dart';
import '../services/pack_trip_service.dart';
import '../services/pack_trip_timing.dart';
import '../services/suitcase_analytics.dart';
import 'widgets/wait/ai_wait_body.dart';
import 'widgets/wait/ai_wait_failure.dart';
import 'widgets/wait/wait_handoff.dart';
import 'widgets/wait/wait_step_sequence.dart';

export '../model/pack_trip_job.dart';

/// Pagina intera mentre `pack-trip` prepara la valigia. Alla risposta i passi
/// finiscono il racconto, la card si apre e la pagina torna con il
/// [AiPackingResult]; "Annulla" torna con null; un errore mostra la sua uscita.
class AiPackingWaitScreen extends ConsumerStatefulWidget {
  const AiPackingWaitScreen({
    super.key,
    required this.tripId,
    required this.job,
  });

  final String tripId;
  final PackTripJob job;

  @override
  ConsumerState<AiPackingWaitScreen> createState() =>
      _AiPackingWaitScreenState();
}

class _AiPackingWaitScreenState extends ConsumerState<AiPackingWaitScreen> {
  late final PackTripService _service;
  final _cardKey = GlobalKey();
  WaitStepSequence? _steps;
  Rect? _handoff;

  /// Errore da mostrare; null mentre la richiesta è in corso.
  Object? _failure;

  /// La valigia è arrivata.
  AiPackingResult? _result;

  /// Un'uscita è già partita: nessun'altra può fare pop (chiuderebbe il chiamante).
  bool _leaving = false;

  /// Durata del tentativo in corso, anche per l'annullamento.
  final _timer = Stopwatch();

  @override
  void initState() {
    super.initState();
    _service = ref.read(packTripServiceProvider);
    _generate();
  }

  @override
  void dispose() {
    _steps?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    _steps?.dispose();
    _steps = null;
    setState(() => _failure = null);
    _timer
      ..reset()
      ..start();
    final started = PackTripTiming.load().then(_startSteps);

    AiPackingResult? result;
    Object? failure;
    StackTrace? failureStack;
    try {
      result = await _service.generate(
        widget.job.body,
        houseId: widget.job.houseId,
      );
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
    await started;

    // Annullata o già in uscita: la pagina non deve più fare niente (un
    // annullamento ha già registrato il suo esito).
    if (_leaving || !mounted) return;
    ref.invalidate(gptUsageProvider);
    _trackFinished(packOutcomeOf(failure, cancelled: false), result);

    if (result == null) {
      // Offline e casi previsti (crediti, armadio) non sono guasti da segnalare.
      if (failure is PackTripException &&
          failure is! PackTripNetworkException) {
        ref
            .read(monitoringServiceProvider)
            .captureException(failure, stackTrace: failureStack);
      }
      _steps?.dispose();
      _steps = null;
      setState(() => _failure = failure);
      return;
    }
    unawaited(PackTripTiming.record(_timer.elapsed));
    _arrived(result);
  }

  void _startSteps(int averageMs) {
    if (!mounted || _leaving) return;
    _steps?.dispose();
    _steps =
        WaitStepSequence(
            stepDuration: Duration(milliseconds: averageMs ~/ kWaitSteps),
            onFinished: _openOnSuitcase,
          )
          ..addListener(() => setState(() {}))
          ..start();
  }

  /// Valigia pronta: i passi finiscono il racconto; senza animazioni, via subito.
  void _arrived(AiPackingResult result) {
    setState(() => _result = result);
    final steps = _steps;
    if (steps == null || MediaQuery.disableAnimationsOf(context)) {
      return _exit(result);
    }
    steps.arrive();
  }

  void _exit(AiPackingResult result) =>
      _leave(() => context.pop<AiPackingResult>(result));

  void _openOnSuitcase() {
    final result = _result;
    if (result == null || _leaving || !mounted) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _exit(result);
    setState(() => _handoff = box.localToGlobal(Offset.zero) & box.size);
  }

  /// Unica porta d'uscita: la prima chiamata vince, le altre non fanno nulla.
  void _leave(VoidCallback exit) {
    if (_leaving) return;
    _leaving = true;
    _steps?.dispose();
    exit();
  }

  void _cancel() {
    if (_result != null) return;
    // Annullata mentre la richiesta era in corso; dalla pagina d'errore
    // l'esito è già stato registrato.
    if (_failure == null && !_leaving) _trackFinished('cancelled', null);
    _leave(() {
      _service.cancel();
      ref.invalidate(gptUsageProvider);
      context.pop();
    });
  }

  /// `ai_suitcase_finished`, una volta per tentativo. Armadio e meteo solo
  /// se già caricati: qui non si avviano richieste.
  void _trackFinished(String outcome, AiPackingResult? result) {
    _timer.stop();
    final analytics = ref.read(coreAnalyticsServiceProvider);
    if (outcome == 'credits') {
      analytics.trackAiLimitReached(feature: 'suitcase');
    }

    final job = widget.job;
    final trip = ref
        .read(tripNotifierProvider)
        .valueOrNull
        ?.where((t) => t.id == widget.tripId)
        .firstOrNull;
    final items = ref.exists(itemNotifierProvider(job.houseId))
        ? ref.read(itemNotifierProvider(job.houseId)).valueOrNull
        : null;
    final weatherState = ref.exists(tripWeatherNotifierProvider(widget.tripId))
        ? ref.read(tripWeatherNotifierProvider(widget.tripId)).valueOrNull
        : null;
    final days = daysToDeparture(trip?.departureDateTime, DateTime.now());
    analytics.trackAiSuitcaseFinished(
      outcome: outcome,
      durationMs: _timer.elapsedMilliseconds,
      tripId: widget.tripId,
      properties: {
        'nights': job.nights,
        'stops': trip?.aiSetup?.stops.length ?? 0,
        'is_regeneration': job.isRegeneration,
        'setup_changed': job.setupChanged,
        'days_to_departure': ?days,
        if (result != null) 'proposal_items': result.proposal.length,
        if (result != null) 'slots_count': result.slots?.length ?? 0,
        ...wardrobeStats(items ?? const []),
        if (trip != null)
          ...tripContext(
            trip,
            luggage: job.luggage,
            weather: weatherState is TripWeatherReady
                ? weatherState.weather
                : null,
          ),
      },
    );
  }

  void _leaveFor(String location) => _leave(() {
    final router = GoRouter.of(context);
    context.pop();
    router.push(location);
  });

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return PopScope(
      // Indietro passa dalla porta d'uscita: in attesa = Annulla, in errore = Chiudi.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (failure == null) {
          _cancel();
        } else {
          _leave(() => context.pop());
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
                child: failure == null
                    ? AiWaitBody(
                        job: widget.job,
                        tripId: widget.tripId,
                        steps: _steps,
                        cardKey: _cardKey,
                        onCancel: _cancel,
                        canCancel: _result == null,
                      )
                    : AiWaitFailure(
                        failure: failure,
                        houseId: widget.job.houseId,
                        onRetry: _generate,
                        onClose: () => _leave(() => context.pop()),
                        onGoTo: _leaveFor,
                      ),
              ),
            ),
            if (_handoff case final from?)
              WaitHandoff(from: from, onDone: () => _exit(_result!)),
          ],
        ),
      ),
    );
  }
}
