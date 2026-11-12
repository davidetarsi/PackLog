import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../monitoring/monitoring_service.dart';
import 'sync_run_state.dart';
import 'sync_session.dart';
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
  int? _runningOperationId;
  int? _runningEpoch;
  int _sessionEpoch = 0;
  bool _sessionReady = false;
  bool _needsRestore = false;
  Future<bool> Function()? _prepareCurrentSession;
  final SyncLocalWriteBarrier _writeBarrier = SyncLocalWriteBarrier();
  Future<void> _sessionQueue = Future<void>.value();
  bool _pullPending = false;
  bool _pushPending = false;
  bool _resetRetriesPending = false;
  String? _pendingPullUserId;
  String? _currentUserId;
  int _operationId = 0;
  int _drainToken = 0;
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
  }) : _connectivity = connectivity ?? Connectivity() {
    _syncService.bindSessionBarrier(_writeBarrier);
  }

  SyncRunState get state => _state;
  bool get needsRestore => _needsRestore;
  bool get sessionReady => _sessionReady;
  String? get currentUserId => _currentUserId;
  int get sessionEpoch => _sessionEpoch;

  /// Captures the current authenticated owner for a short local write.
  SyncSessionContext? captureLocalWriteContext() {
    if (!_sessionReady || _currentUserId == null || _disposed) return null;
    try {
      return _writeBarrier.capture(_currentUserId);
    } on SyncSessionInvalid {
      return null;
    }
  }

  bool isLocalWriteContextCurrent(SyncSessionContext context) =>
      _sessionReady && !_disposed && _writeBarrier.isCurrent(context);

  /// Serializes local commit work; the callback owns its database transaction.
  Future<T> commitLocalWrite<T>(
    SyncSessionContext context,
    Future<T> Function() write,
  ) => _writeBarrier.commit(context, write);
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
    _writeBarrier.dispose();
    _sessionEpoch++;
    _sessionReady = false;
    _pullPending = false;
    _pushPending = false;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    unawaited(_states.close());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userId = _currentUserId;
      if (userId != null && _sessionReady) {
        _requestPull(userId, resetRetries: true, epoch: _sessionEpoch);
      }
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_hasNetwork(results)) return;
    final userId = _currentUserId;
    if (userId != null && _sessionReady) {
      _requestPull(userId, resetRetries: true, epoch: _sessionEpoch);
    }
  }

  void requestSync() => _requestPush('local_mutation');

  void requestForcedSync() => _requestPush('forced_sync', resetRetries: true);

  Future<void> replaceSession(
    String? userId, {
    required Future<bool> Function() prepareLocalData,
  }) {
    final epoch = ++_sessionEpoch;
    _sessionReady = false;
    _needsRestore = false;
    _currentUserId = userId;
    _prepareCurrentSession = userId == null ? null : prepareLocalData;
    _pullPending = false;
    _pendingPullUserId = null;
    _pushPending = false;
    _resetRetriesPending = false;
    _running = false;
    _runningEpoch = null;
    _runningOperationId = null;
    _writeBarrier.beginSwitch(epoch);
    _publish(
      userId == null ? const SyncSignedOut() : const SyncSwitchingSession(),
    );

    final previous = _sessionQueue;
    final completed = Completer<void>();
    _sessionQueue = completed.future;
    return () async {
      try {
        await previous;
        if (!_isCurrentEpoch(epoch)) return;
        await _syncService.drainLocalWrites();
        if (!_isCurrentEpoch(epoch)) return;
        if (userId == null) {
          await prepareLocalData();
          if (!_isCurrentEpoch(epoch)) return;
          _writeBarrier.signOut(epoch);
          _publish(const SyncSignedOut());
          return;
        }
        _needsRestore = await prepareLocalData();
        if (!_isCurrentEpoch(epoch)) return;
        final context = _writeBarrier.createContext(epoch, userId);
        _writeBarrier.activate(context);
        _sessionReady = true;
        _publish(const SyncIdle());
        if (_isCurrentEpoch(epoch) && _sessionReady) {
          _requestPull(userId, epoch: epoch);
        }
      } catch (e, st) {
        if (_isCurrentEpoch(epoch)) {
          _sessionReady = false;
          _needsRestore = userId != null;
          _publish(
            const SyncFailed(
              SyncFailureCode.service,
              isPreparationFailure: true,
            ),
          );
          _captureFailure(e, st, 'orchestrator_prepare_session');
        }
      } finally {
        completed.complete();
      }
    }();
  }

  Future<void> retrySessionPreparation() {
    final userId = _currentUserId;
    final prepare = _prepareCurrentSession;
    if (userId == null || prepare == null || _sessionReady) {
      return Future<void>.value();
    }
    return replaceSession(userId, prepareLocalData: prepare);
  }

  void requestFullPull(String userId) {
    if (_sessionReady && userId == _currentUserId) {
      _requestPull(userId, epoch: _sessionEpoch);
    }
  }

  bool _isCurrentEpoch(int epoch) => !_disposed && epoch == _sessionEpoch;

  Future<void> _requestPush(String trigger, {bool resetRetries = false}) async {
    if (!_sessionReady || _currentUserId == null) return;
    final epoch = _sessionEpoch;
    final online = await _isOnline(epoch);
    if (!_isCurrentEpoch(epoch) || !_sessionReady) return;
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

  Future<void> _requestPull(
    String userId, {
    bool resetRetries = false,
    required int epoch,
  }) async {
    final online = await _isOnline(epoch);
    if (!_isCurrentEpoch(epoch) || !_sessionReady || userId != _currentUserId) {
      return;
    }
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

  Future<bool?> _isOnline(int epoch) async {
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } catch (e, st) {
      if (_isCurrentEpoch(epoch)) {
        _monitoring.captureException(
          e,
          stackTrace: st,
          tags: const {'operation': 'orchestrator_connectivity'},
        );
      }
      if (_isCurrentEpoch(epoch) && !_running) {
        _publish(const SyncFailed(SyncFailureCode.network));
      }
      return null;
    }
  }

  Future<void> _drain() async {
    if (_disposed || !_sessionReady) return;
    if (_running && _runningEpoch == _sessionEpoch) return;
    final epoch = _sessionEpoch;
    final drainToken = ++_drainToken;
    _running = true;
    _runningEpoch = epoch;
    _runningOperationId = drainToken;
    var failed = false;
    try {
      while (_isCurrentEpoch(epoch) &&
          _sessionReady &&
          (_pullPending || _pushPending)) {
        if (_pullPending) {
          final userId = _pendingPullUserId!;
          _pullPending = false;
          _pendingPullUserId = null;
          final reset = _takeResetIntent();
          if (!await _runPull(userId, epoch: epoch, resetRetries: reset)) {
            if (_isCurrentEpoch(epoch) && !_pullPending && !_pushPending) {
              failed = true;
              break;
            }
            continue;
          }
          if (!_isCurrentEpoch(epoch)) break;
          failed = false;
          try {
            final pending = await _syncService.countPendingChanges();
            if (_isCurrentEpoch(epoch) && pending > 0) {
              _pushPending = true;
              _pushTrigger = 'full_pull_auto_flush';
            }
          } catch (e, st) {
            if (_isCurrentEpoch(epoch)) {
              _monitoring.captureException(
                e,
                stackTrace: st,
                tags: const {'operation': 'orchestrator_autoFlush_count'},
              );
            }
          }
        } else if (_pushPending) {
          _pushPending = false;
          final trigger = _pushTrigger;
          final reset = _takeResetIntent();
          if (!await _runPush(trigger, epoch: epoch, resetRetries: reset)) {
            if (_isCurrentEpoch(epoch) && !_pullPending && !_pushPending) {
              failed = true;
              break;
            }
            continue;
          }
          failed = false;
        }
      }
    } finally {
      if (_runningOperationId == drainToken) {
        _running = false;
        _runningEpoch = null;
        _runningOperationId = null;
        if (_isCurrentEpoch(epoch) && !failed) {
          _publish(const SyncIdle());
        }
        if (_isCurrentEpoch(epoch) &&
            !failed &&
            (_pullPending || _pushPending)) {
          unawaited(_drain());
        }
      }
    }
  }

  bool _takeResetIntent() {
    final reset = _resetRetriesPending;
    _resetRetriesPending = false;
    return reset;
  }

  Future<bool> _runPull(
    String userId, {
    required int epoch,
    required bool resetRetries,
  }) async {
    final operationId = ++_operationId;
    _publish(
      SyncRunning(
        operation: SyncOperationKind.pull,
        operationId: operationId,
        sessionEpoch: epoch,
      ),
    );
    onFullPullStart?.call();
    _monitoring.logBreadcrumb('Avvio fullPull', category: 'sync');
    try {
      if (resetRetries) await _syncService.resetAllSyncRetries();
      if (!_isCurrentEpoch(epoch)) return false;
      await _syncService.fullPull(userId);
      if (!_isCurrentEpoch(epoch)) return false;
      _needsRestore = false;
      onFullPullComplete?.call();
      return true;
    } on SyncSessionInvalid {
      return false;
    } catch (e, st) {
      if (_isCurrentEpoch(epoch)) {
        _captureFailure(e, st, 'orchestrator_fullPull');
        _publish(SyncFailed(_failureCode(e)));
      }
      return false;
    }
  }

  Future<bool> _runPush(
    String trigger, {
    required int epoch,
    required bool resetRetries,
  }) async {
    final operationId = ++_operationId;
    _publish(
      SyncRunning(
        operation: SyncOperationKind.push,
        operationId: operationId,
        sessionEpoch: epoch,
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
      if (!_isCurrentEpoch(epoch)) return false;
      await _syncService.processQueue();
      return _isCurrentEpoch(epoch);
    } on SyncSessionInvalid {
      return false;
    } catch (e, st) {
      if (_isCurrentEpoch(epoch)) {
        _captureFailure(e, st, 'orchestrator_processQueue', trigger: trigger);
        _publish(SyncFailed(_failureCode(e)));
      }
      return false;
    } finally {
      if (_isCurrentEpoch(epoch)) onProcessQueueComplete?.call();
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
