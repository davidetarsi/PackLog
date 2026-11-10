import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_spacing.dart';
import '../model/ai_packing_request.dart';
import '../providers/ai_packing_run_provider.dart';
import '../services/pack_trip_timing.dart';
import 'widgets/wait/ai_wait_body.dart';
import 'widgets/wait/ai_wait_failure.dart';
import 'widgets/wait/wait_handoff.dart';
import 'widgets/wait/wait_step_sequence.dart';

export '../model/pack_trip_job.dart';

/// Pagina intera mentre il lavoro AI ([aiPackingRunProvider]) prepara la
/// valigia. Non chiama niente: mostra lo stato. Indietro la stacca e il
/// lavoro continua; all'arrivo i passi finiscono il racconto, la card si apre
/// e la pagina va al dettaglio del viaggio in revisione; un errore mostra la
/// sua uscita.
class AiPackingWaitScreen extends ConsumerStatefulWidget {
  const AiPackingWaitScreen({super.key});

  @override
  ConsumerState<AiPackingWaitScreen> createState() =>
      _AiPackingWaitScreenState();
}

class _AiPackingWaitScreenState extends ConsumerState<AiPackingWaitScreen> {
  late final AiPackingRun _run;
  final _cardKey = GlobalKey();
  WaitStepSequence? _steps;
  Rect? _handoff;

  /// L'ultima richiesta vista: la pagina resta leggibile anche dopo il
  /// [AiRunDone], quando lo stato non la porta più.
  AiPackingRequest? _request;

  /// La valigia è arrivata, sul viaggio con questo id.
  String? _doneTripId;

  /// Un'uscita è già partita: nessun'altra può navigare (due uscite
  /// chiuderebbero anche la pagina sotto).
  bool _leaving = false;

  /// I tempi dei passi si stanno caricando.
  bool _loadingSteps = false;

  @override
  void initState() {
    super.initState();
    _run = ref.read(aiPackingRunProvider.notifier)..attach();
    final state = ref.read(aiPackingRunProvider);
    _request = _requestOf(state);
    // Il lavoro può essere già finito prima che la pagina si veda.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(ref.read(aiPackingRunProvider));
    });
  }

  @override
  void dispose() {
    _steps?.dispose();
    _run.detach();
    super.dispose();
  }

  AiPackingRequest? _requestOf(AiPackingRunState state) => switch (state) {
    AiRunRunning(:final request) => request,
    AiRunFailed(:final request) => request,
    _ => null,
  };

  void _sync(AiPackingRunState state) {
    if (_leaving) return;
    switch (state) {
      case AiRunRunning(:final request):
        _request = request;
        _startSteps();
      case AiRunFailed(:final request):
        _request = request;
        _stopSteps();
      case AiRunDone(:final tripId):
        _arrived(tripId);
      case AiRunIdle():
        // Niente da mostrare (lavoro azzerato): si lascia la pagina.
        if (_doneTripId == null) _close(clear: false);
    }
  }

  Future<void> _startSteps() async {
    if (_steps != null || _loadingSteps) return;
    _loadingSteps = true;
    final averageMs = await PackTripTiming.load();
    _loadingSteps = false;
    if (!mounted || _leaving || _steps != null || _doneTripId != null) return;
    if (ref.read(aiPackingRunProvider) is! AiRunRunning) return;
    _steps =
        WaitStepSequence(
            stepDuration: Duration(milliseconds: averageMs ~/ kWaitSteps),
            onFinished: _openOnSuitcase,
          )
          ..addListener(() => setState(() {}))
          ..start();
    setState(() {});
  }

  void _stopSteps() {
    _steps?.dispose();
    setState(() => _steps = null);
  }

  /// Valigia pronta: i passi finiscono il racconto; senza animazioni, via subito.
  void _arrived(String tripId) {
    if (_doneTripId != null) return;
    setState(() => _doneTripId = tripId);
    final steps = _steps;
    if (steps == null || MediaQuery.disableAnimationsOf(context)) {
      return _openReview();
    }
    steps.arrive();
  }

  void _openOnSuitcase() {
    if (_doneTripId == null || _leaving || !mounted) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _openReview();
    setState(() => _handoff = box.localToGlobal(Offset.zero) & box.size);
  }

  /// Unica porta d'uscita: la prima chiamata vince, le altre non fanno nulla.
  void _leave(VoidCallback exit) {
    if (_leaving) return;
    _leaving = true;
    _steps?.dispose();
    exit();
  }

  /// Al dettaglio in revisione, poi il lavoro si azzera.
  void _openReview() {
    final tripId = _doneTripId;
    if (tripId == null) return;
    _leave(() {
      context.go('/trips/$tripId?review=1');
      _run.clear();
    });
  }

  /// Indietro in attesa: la pagina si stacca e il lavoro continua; ad
  /// arrivare ci pensa l'avviso globale. Il passo 1 che ha avviato il lavoro
  /// si chiude con la pagina (niente è salvato, i dati sono nel lavoro): si
  /// va ai Viaggi, o al dettaglio se è una Rigenera.
  void _stay() => _leave(() {
    _run.detach();
    final request = _request;
    context.go(
      request == null || request.isNew ? '/trips' : '/trips/${request.trip.id}',
    );
  });

  /// Chiude un errore (o una pagina senza lavoro): [clear] azzera il lavoro.
  void _close({bool clear = true}) => _leave(() {
    if (clear) _run.clear();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/trips');
    }
  });

  void _goTo(String location) => _leave(() {
    _run.clear();
    final router = GoRouter.of(context);
    context.pop();
    router.push(location);
  });

  @override
  Widget build(BuildContext context) {
    ref.listen(aiPackingRunProvider, (_, next) => _sync(next));
    final state = ref.watch(aiPackingRunProvider);
    final request = _requestOf(state) ?? _request;
    final failed = state is AiRunFailed;

    return PopScope(
      // Indietro passa dalla porta d'uscita: in attesa si stacca, a valigia
      // arrivata apre la revisione, in errore chiude.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state is AiRunFailed) {
          _close();
        } else if (_doneTripId != null) {
          _openReview();
        } else {
          _stay();
        }
      },
      child: Scaffold(
        body: request == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacingLg,
                      ),
                      child: failed
                          ? AiWaitFailure(
                              failure: state.error,
                              houseId: request.job.houseId,
                              onRetry: _run.retry,
                              onClose: _close,
                              onGoTo: _goTo,
                            )
                          : AiWaitBody(
                              job: request.job,
                              tripId: request.trip.id,
                              steps: _steps,
                              cardKey: _cardKey,
                            ),
                    ),
                  ),
                  if (_handoff case final from?)
                    WaitHandoff(from: from, onDone: _openReview),
                ],
              ),
      ),
    );
  }
}
