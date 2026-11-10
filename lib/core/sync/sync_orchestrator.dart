import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../monitoring/monitoring_service.dart';
import 'sync_run_state.dart';
import 'sync_service.dart';

class SyncOrchestrator with WidgetsBindingObserver {
  final SyncService _syncService;
  final AppMonitoringService _monitoring;
  final Connectivity _connectivity;
  final StreamController<SyncRunState> _states =
      StreamController<SyncRunState>.broadcast();

  SyncRunState _state = const SyncIdle();
  bool _disposed = false;
  bool _running = false;
  bool _pullPending = false;
  bool _pushPending = false;
  bool _resetRetriesPending = false;
  String? _pendingPullUserId;
  String? _currentUserId;
  int _operationId = 0;
  String _pushTrigger = 'local_mutation';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Callback UI conservate per compatibilità con i chiamanti esistenti.
  void Function()? onFullPullStart;
  void Function()? onFullPullComplete;
  void Function()? onSyncStarted;
  void Function()? onProcessQueueComplete;

  SyncOrchestrator(
    this._syncService,
    this._monitoring, {
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  SyncRunState get state => _state;
  Stream<SyncRunState> get states => Stream<SyncRunState>.multi((controller) {
    // Attach first, then read the snapshot: this closes the gap where a state
    // could change after the snapshot read but before stream subscription.
    final subscription = _states.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_state);
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void _publish(SyncRunState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    unawaited(_states.close());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userId = _currentUserId;
      if (userId != null) _requestPull(userId, resetRetries: true);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_hasNetwork(results)) return;
    final userId = _currentUserId;
    if (userId != null) {
      _requestPull(userId, resetRetries: true);
    } else {
      _requestPush('connectivity_restored');
    }
  }

  void requestSync() => _requestPush('local_mutation');

  void requestForcedSync() => _requestPush('forced_sync', resetRetries: true);

  void requestFullPull(String userId) {
    _currentUserId = userId;
    _requestPull(userId);
  }

  Future<void> _requestPush(String trigger, {bool resetRetries = false}) async {
    final online = await _isOnline();
    if (online == null) return;
    if (!online) {
      if (!_running) _publish(const SyncOffline());
      return;
    }
    _pushPending = true;
    _pushTrigger = trigger;
    _resetRetriesPending |= resetRetries;
    unawaited(_drain());
  }

  Future<void> _requestPull(String userId, {bool resetRetries = false}) async {
    final online = await _isOnline();
    if (online == null) return;
    if (!online) {
      if (!_running) _publish(const SyncOffline());
      return;
    }
    _pendingPullUserId = userId;
    _pullPending = true;
    _resetRetriesPending |= resetRetries;
    unawaited(_drain());
  }

  Future<bool?> _isOnline() async {
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } catch (e, st) {
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: const {'operation': 'orchestrator_connectivity'},
      );
      if (!_running) _publish(const SyncFailed(SyncFailureCode.network));
      return null;
    }
  }

  Future<void> _drain() async {
    if (_running || _disposed) return;
    _running = true;
    var failed = false;
    try {
      while (!_disposed && (_pullPending || _pushPending)) {
        if (_pullPending) {
          final userId = _pendingPullUserId!;
          _pullPending = false;
          _pendingPullUserId = null;
          final reset = _takeResetIntent();
          if (!await _runPull(userId, resetRetries: reset)) {
            if (!_pullPending && !_pushPending) {
              failed = true;
              break;
            }
            continue;
          }
          failed = false;
          // Il pull può produrre record locali pending. Accoda un solo push.
          try {
            final pending = await _syncService.countPendingChanges();
            if (pending > 0) {
              _pushPending = true;
              _pushTrigger = 'full_pull_auto_flush';
            }
          } catch (e, st) {
            _monitoring.captureException(
              e,
              stackTrace: st,
              tags: const {'operation': 'orchestrator_autoFlush_count'},
            );
          }
        } else if (_pushPending) {
          _pushPending = false;
          final trigger = _pushTrigger;
          final reset = _takeResetIntent();
          if (!await _runPush(trigger, resetRetries: reset)) {
            if (!_pullPending && !_pushPending) {
              failed = true;
              break;
            }
            continue;
          }
          failed = false;
        }
      }
    } finally {
      _running = false;
      if (!_disposed && !failed) {
        _publish(const SyncIdle());
      }
      // Pending explicit work can only be left by a concurrent request during
      // the final state publication; failures deliberately stop this drain.
      if (!_disposed && !failed && (_pullPending || _pushPending)) {
        unawaited(_drain());
      }
    }
  }

  bool _takeResetIntent() {
    final reset = _resetRetriesPending;
    _resetRetriesPending = false;
    return reset;
  }

  Future<bool> _runPull(String userId, {required bool resetRetries}) async {
    final operationId = ++_operationId;
    _publish(
      SyncRunning(
        operation: SyncOperationKind.pull,
        operationId: operationId,
        sessionEpoch: 0,
      ),
    );
    onFullPullStart?.call();
    _monitoring.logBreadcrumb('Avvio fullPull', category: 'sync');
    try {
      if (resetRetries) await _syncService.resetAllSyncRetries();
      await _syncService.fullPull(userId);
      onFullPullComplete?.call();
      return true;
    } catch (e, st) {
      _captureFailure(e, st, 'orchestrator_fullPull');
      _publish(SyncFailed(_failureCode(e)));
      return false;
    }
  }

  Future<bool> _runPush(String trigger, {required bool resetRetries}) async {
    final operationId = ++_operationId;
    _publish(
      SyncRunning(
        operation: SyncOperationKind.push,
        operationId: operationId,
        sessionEpoch: 0,
      ),
    );
    onSyncStarted?.call();
    _monitoring.logBreadcrumb(
      'Avvio sincronizzazione. Trigger: $trigger',
      category: 'sync',
      data: {'trigger': trigger},
    );
    try {
      if (resetRetries) await _syncService.resetAllSyncRetries();
      await _syncService.processQueue();
      return true;
    } catch (e, st) {
      _captureFailure(e, st, 'orchestrator_processQueue', trigger: trigger);
      _publish(SyncFailed(_failureCode(e)));
      return false;
    } finally {
      onProcessQueueComplete?.call();
    }
  }

  void _captureFailure(
    Object error,
    StackTrace stackTrace,
    String operation, {
    String? trigger,
  }) {
    _monitoring.captureException(
      error,
      stackTrace: stackTrace,
      tags: {'operation': operation, if (trigger != null) 'trigger': trigger},
    );
  }

  SyncFailureCode _failureCode(Object error) => error is TimeoutException
      ? SyncFailureCode.network
      : SyncFailureCode.service;

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
