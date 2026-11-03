import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../profile/providers/gpt_usage_provider.dart';
import '../model/ai_packing.dart';
import '../model/pack_trip_job.dart';
import '../services/pack_trip_service.dart';
import '../services/pack_trip_timing.dart';
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
    final timer = Stopwatch()..start();
    final started = PackTripTiming.load().then(_startSteps);

    AiPackingResult? result;
    Object? failure;
    try {
      result = await _service.generate(
        widget.job.body,
        houseId: widget.job.houseId,
      );
    } catch (error) {
      failure = error;
    }
    await started;

    // Annullata o già in uscita: la pagina non deve più fare niente.
    if (_leaving || !mounted) return;
    ref.invalidate(gptUsageProvider);

    if (result == null) {
      _steps?.dispose();
      _steps = null;
      setState(() => _failure = failure);
      return;
    }
    unawaited(PackTripTiming.record(timer.elapsed));
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
    _leave(() {
      _service.cancel();
      ref.invalidate(gptUsageProvider);
      context.pop();
    });
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
