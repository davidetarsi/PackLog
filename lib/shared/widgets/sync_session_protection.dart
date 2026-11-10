import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/sync/sync_orchestrator.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/sync/sync_run_state.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/luggages/providers/luggage_provider.dart';
import '../../features/trips/providers/trip_provider.dart';
import 'ds_error_state.dart';

/// Keeps cached screens inaccessible while a newly prepared account loads its
/// local data. The cloud pull is deliberately not part of this gate.
class SyncSessionProtection extends ConsumerStatefulWidget {
  const SyncSessionProtection({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncSessionProtection> createState() =>
      _SyncSessionProtectionState();
}

class _SyncSessionProtectionState extends ConsumerState<SyncSessionProtection> {
  SyncOrchestrator? _owner;
  int? _epoch;
  bool _cacheGate = false;

  @override
  Widget build(BuildContext context) {
    final orchestrator = ref.watch(syncOrchestratorProvider);
    ref.watch(syncRunStateProvider);
    final runState = orchestrator.state;
    final isSignedOut = runState is SyncSignedOut;
    final isSwitching = runState is SyncSwitchingSession;
    final isPreparationFailure =
        runState is SyncFailed && runState.isPreparationFailure;

    if (isSignedOut || orchestrator.currentUserId == null) {
      _owner = orchestrator;
      _epoch = orchestrator.sessionEpoch;
      _cacheGate = false;
      return widget.child;
    }

    final sessionKeyChanged =
        !identical(_owner, orchestrator) || _epoch != orchestrator.sessionEpoch;
    if (sessionKeyChanged) {
      _owner = orchestrator;
      _epoch = orchestrator.sessionEpoch;
      _cacheGate = true;
    }

    if (isSwitching || isPreparationFailure || !orchestrator.sessionReady) {
      _cacheGate = true;
      return _cover(
        context,
        runState: runState,
        preparationFailure: isPreparationFailure,
      );
    }

    if (_cacheGate) {
      final houses = ref.watch(houseNotifierProvider);
      final trips = ref.watch(tripNotifierProvider);
      final luggages = ref.watch(luggageNotifierProvider);
      final hasError =
          _hasSettledError(houses) ||
          _hasSettledError(trips) ||
          _hasSettledError(luggages);
      final ready =
          _hasFreshData(houses) &&
          _hasFreshData(trips) &&
          _hasFreshData(luggages);
      if (ready) {
        _cacheGate = false;
        return widget.child;
      }
      return _cover(context, runState: runState, cacheFailure: hasError);
    }

    return widget.child;
  }

  bool _hasFreshData(AsyncValue<dynamic> value) =>
      value is AsyncData<dynamic> && !value.isLoading;

  bool _hasSettledError(AsyncValue<dynamic> value) =>
      value.hasError && !value.isLoading;

  Widget _cover(
    BuildContext context, {
    SyncRunState? runState,
    bool preparationFailure = false,
    bool cacheFailure = false,
  }) {
    final hasError = preparationFailure || cacheFailure;
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          child: ExcludeFocus(child: ExcludeSemantics(child: widget.child)),
        ),
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        if (hasError)
          DsErrorState(
            error: runState is SyncFailed
                ? runState.code
                : 'Local cache failed',
            onRetry: preparationFailure ? _retryPreparation : _retryCaches,
            title: 'errors.load_failed'.tr(),
            message: 'errors.retry_hint'.tr(),
          )
        else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  void _retryPreparation() {
    ref.read(syncOrchestratorProvider).retrySessionPreparation();
  }

  void _retryCaches() {
    ref.invalidate(houseNotifierProvider);
    ref.invalidate(tripNotifierProvider);
    ref.invalidate(luggageNotifierProvider);
  }
}
