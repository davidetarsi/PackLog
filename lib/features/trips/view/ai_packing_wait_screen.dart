import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../profile/providers/gpt_usage_provider.dart';
import '../model/ai_packing.dart';
import '../services/pack_trip_service.dart';

/// Ciò che serve a `pack-trip` per generare la valigia, e a mostrare l'attesa.
class PackTripJob {
  const PackTripJob({
    required this.body,
    required this.houseId,
    required this.title,
    required this.nights,
  });

  /// Corpo della richiesta a `pack-trip`.
  final Map<String, dynamic> body;

  /// Casa da cui arrivano i vestiti.
  final String houseId;

  /// Tappe del viaggio, come si leggono nell'attesa ("Islanda e Olanda").
  final String title;

  final int nights;
}

/// Pagina intera mentre `pack-trip` prepara la valigia. Alla risposta torna
/// indietro con il [AiPackingResult]; con "Annulla" torna indietro con null;
/// in caso di errore mostra un messaggio con la sua uscita.
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

/// Momenti in cui il passo successivo si accende, dopo l'inizio. Sono a
/// tempo, non legati a eventi reali del server.
const _stepStarts = [Duration(seconds: 3), Duration(seconds: 6)];

class _AiPackingWaitScreenState extends ConsumerState<AiPackingWaitScreen> {
  late final PackTripService _service;
  final List<Timer> _timers = [];

  /// Passo in corso: 0, 1 o 2.
  int _step = 0;

  /// Errore da mostrare; null mentre la richiesta è in corso.
  Object? _failure;

  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    // Stesso servizio per generare e per annullare: il provider non è keepAlive.
    _service = ref.read(packTripServiceProvider);
    _generate();
  }

  @override
  void dispose() {
    _stopSteps();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _failure = null;
      _step = 0;
    });
    _startSteps();

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
    _stopSteps();

    // Annullata: la pagina è già chiusa e non c'è più niente da mostrare.
    if (_cancelled || !mounted) return;
    ref.invalidate(gptUsageProvider);

    if (result != null) {
      context.pop<AiPackingResult>(result);
      return;
    }
    setState(() => _failure = failure);
  }

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _stopSteps();
    _service.cancel();
    ref.invalidate(gptUsageProvider);
    context.pop();
  }

  /// Chiude questa pagina e apre [location] sopra la pagina che l'ha chiamata.
  void _leaveFor(String location) {
    final router = GoRouter.of(context);
    context.pop();
    router.push(location);
  }

  void _startSteps() {
    _stopSteps();
    for (var i = 0; i < _stepStarts.length; i++) {
      _timers.add(
        Timer(_stepStarts[i], () {
          if (mounted) setState(() => _step = i + 1);
        }),
      );
    }
  }

  void _stopSteps() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return PopScope(
      // Il tasto indietro durante l'attesa vale come "Annulla".
      canPop: failure != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: failure == null
                ? _buildWaiting(context)
                : _buildFailure(context, failure),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nights = 'trips.ai.wait.nights'.plural(widget.job.nights);
    final steps = [
      'trips.ai.wait.step_weather'.tr(args: [widget.job.title]),
      'trips.ai.wait.step_wardrobe'.tr(),
      'trips.ai.wait.step_check'.tr(),
    ];

    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: AppSpacing.iconXl,
                color: colorScheme.onSurfaceVariant,
              ),
              AppSpacing.gapLg,
              Text(
                'trips.ai.wait.title'.tr(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppSpacing.gapSm,
              Text(
                'trips.ai.wait.subtitle'.tr(args: [widget.job.title, nights]),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapLg,
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) AppSpacing.gapMd,
                _WaitStep(
                  label: steps[i],
                  state: i < _step
                      ? _StepState.done
                      : i == _step
                      ? _StepState.current
                      : _StepState.pending,
                ),
              ],
              AppSpacing.gapLg,
              Text(
                'trips.ai.wait.hint'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size(0, 48),
            ),
            child: Text('common.cancel'.tr()),
          ),
        ),
        AppSpacing.gapXl,
      ],
    );
  }

  Widget _buildFailure(BuildContext context, Object failure) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String title;
    final String body;
    final String primaryLabel;
    final VoidCallback primaryAction;
    var showExit = true;

    switch (failure) {
      case PackTripCreditsException():
        title = 'trips.ai.error.credits_title'.tr();
        body = 'trips.ai.error.credits_body'.tr();
        primaryLabel = 'trips.ai.error.credits_action'.tr();
        primaryAction = () => _leaveFor('/profile');
      case PackTripEmptyWardrobeException():
        title = 'trips.ai.error.empty_title'.tr();
        body = 'trips.ai.error.empty_body'.tr();
        primaryLabel = 'trips.ai.error.empty_action'.tr();
        final houseId = widget.job.houseId;
        primaryAction = () => _leaveFor('/houses/$houseId');
      case PackTripWardrobeTooLargeException():
        // Un'unica uscita: è anche l'azione principale.
        title = 'trips.ai.error.too_large_title'.tr();
        body = 'trips.ai.error.too_large_body'.tr();
        primaryLabel = 'common.close'.tr();
        primaryAction = () => context.pop();
        showExit = false;
      default:
        title = 'trips.ai.error.generic_title'.tr();
        body = 'trips.ai.error.generic_body'.tr();
        primaryLabel = 'common.retry'.tr();
        primaryAction = _generate;
    }

    return Column(
      children: [
        const Spacer(),
        Icon(
          Icons.error_outline,
          size: AppSpacing.iconXl,
          color: colorScheme.onSurfaceVariant,
        ),
        AppSpacing.gapLg,
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        AppSpacing.gapSm,
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        DsButton(label: primaryLabel, onPressed: primaryAction, expand: true),
        if (showExit)
          TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text('common.close'.tr()),
          ),
        AppSpacing.gapXl,
      ],
    );
  }
}

enum _StepState { done, current, pending }

/// Un passo dell'attesa: spunta se fatto, anello se in corso, puntino se
/// ancora da fare.
class _WaitStep extends StatelessWidget {
  const _WaitStep({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Widget marker;
    final TextStyle? style;
    switch (state) {
      case _StepState.done:
        marker = Icon(Icons.check, size: 22, color: colorScheme.onSurface);
        style = theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
      case _StepState.current:
        marker = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        style = theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        );
      case _StepState.pending:
        marker = Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            shape: BoxShape.circle,
          ),
        );
        style = theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline);
    }

    return Row(
      children: [
        SizedBox(width: 22, height: 22, child: Center(child: marker)),
        AppSpacing.hGapMd,
        Expanded(child: Text(label, style: style)),
      ],
    );
  }
}
