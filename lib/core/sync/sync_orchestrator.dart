import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../monitoring/monitoring_service.dart';
import 'sync_service.dart';

class SyncOrchestrator with WidgetsBindingObserver {
  final SyncService _syncService;
  final AppMonitoringService _monitoring;
  final Connectivity _connectivity;
  bool _isSyncing = false;
  String? _currentUserId;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Chiamato da [sync_provider] appena prima di avviare un fullPull.
  /// Usato per segnalare all'UI che un pull remoto è in corso.
  void Function()? onFullPullStart;

  /// Chiamato da [sync_provider] dopo ogni fullPull riuscito.
  /// Usato per notificare i notifier dei dati di rifetchare.
  void Function()? onFullPullComplete;

  /// Chiamato immediatamente prima di ogni `processQueue` (push) che parte
  /// davvero (dopo che il mutex è stato acquisito). Non chiamato quando il
  /// mutex scarta un sync concorrente.
  ///
  /// Usato da [sync_provider] per invalidare subito `pendingChangesCountProvider`
  /// così la `SyncStatusTile` mostra lo stato di caricamento mentre il push
  /// è in corso, invece di restare su un valore cacheato potenzialmente stale.
  void Function()? onSyncStarted;

  /// Chiamato da [sync_provider] dopo ogni tentativo di processQueue (push),
  /// **anche se fallisce**: il numero di record pending può essere cambiato
  /// in entrambi i casi (alcuni passati a `synced`, altri ancora `pending*`)
  /// e la UI counter deve riflettere il nuovo conteggio.
  ///
  /// Non viene chiamato quando il mutex blocca un sync concorrente: in quel
  /// caso il sync in-flight produrrà il proprio callback alla fine.
  void Function()? onProcessQueueComplete;

  SyncOrchestrator(
    this._syncService,
    this._monitoring, {
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userId = _currentUserId;
      if (userId != null) {
        _attemptFullPullIfOnline(userId, resetRetries: true);
      }
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_hasNetwork(results)) {
      final userId = _currentUserId;
      if (userId != null) {
        _attemptFullPullIfOnline(userId, resetRetries: true);
      } else {
        _attemptSync('connectivity_restored');
      }
    }
  }

  /// Triggers sync after a local DB mutation (create/update/delete).
  /// Fire-and-forget: callers should not await this.
  void requestSync() {
    debugPrint('[SyncOrchestrator] requestSync called');
    _attemptSyncIfOnline('local_mutation');
  }

  /// Called from the manual "Sync now" button in profile.
  /// Resets retry counters so records stuck in backoff get a fresh attempt,
  /// then runs processQueue. Fire-and-forget.
  void requestForcedSync() {
    debugPrint('[SyncOrchestrator] requestForcedSync called');
    _attemptForcedSyncIfOnline();
  }

  Future<void> _attemptForcedSyncIfOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (!_hasNetwork(results)) return;
    await _attemptSync('forced_sync', resetRetries: true);
  }

  /// Scarica tutti i record dell'utente da Supabase al DB locale.
  /// Chiamato ad ogni avvio quando l'utente risulta autenticato.
  /// Fire-and-forget: non blocca il chiamante.
  void requestFullPull(String userId) {
    _currentUserId = userId;
    _attemptFullPullIfOnline(userId);
  }

  Future<void> _attemptFullPullIfOnline(
    String userId, {
    bool resetRetries = false,
  }) async {
    final results = await _connectivity.checkConnectivity();
    if (!_hasNetwork(results)) {
      debugPrint('[SyncOrchestrator] fullPull: skipped (no network)');
      return;
    }
    if (_isSyncing) {
      debugPrint('[SyncOrchestrator] fullPull: skipped (already syncing)');
      return;
    }
    _isSyncing = true;
    onFullPullStart?.call();
    _monitoring.logBreadcrumb(
      'Avvio fullPull. userId: $userId',
      category: 'sync',
      data: {'userId': userId},
    );
    try {
      if (resetRetries) await _syncService.resetAllSyncRetries();
      await _syncService.fullPull(userId);
      onFullPullComplete?.call();
      // Auto-flush: chiude la finestra di skip-by-mutex per le mutazioni
      // locali tentate mentre il fullPull era in volo (es. TripNotifier.build()
      // → transferItemsForCompletedTrips → moveItemsToHouse → pendingUpdate).
      // Senza questo, i record resterebbero pending fino al prossimo trigger
      // (mutazione utente, app_resume, connectivity_restored).
      await _flushPendingIfAny();
    } catch (e, st) {
      debugPrint('[SyncOrchestrator] fullPull failed: $e');
      debugPrint('[SyncOrchestrator] Stack trace:\n$st');
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: const {'operation': 'orchestrator_fullPull'},
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Esegue [SyncService.processQueue] solo se ci sono record pending.
  /// Pensato per essere chiamato all'interno del mutex `_isSyncing` da
  /// [_attemptFullPullIfOnline]; non riacquisisce il mutex.
  Future<void> _flushPendingIfAny() async {
    final int pending;
    try {
      pending = await _syncService.countPendingChanges();
    } catch (e, st) {
      debugPrint('[SyncOrchestrator] auto-flush count failed: $e');
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: const {'operation': 'orchestrator_autoFlush_count'},
      );
      return;
    }
    if (pending == 0) return;

    debugPrint('[SyncOrchestrator] Auto-flush: $pending pending record(s)');
    try {
      await _syncService.processQueue();
    } catch (e, st) {
      debugPrint('[SyncOrchestrator] auto-flush processQueue failed: $e');
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: const {'operation': 'orchestrator_autoFlush'},
      );
    } finally {
      // Anche su failure: invalida il counter UI, così la tile riflette
      // quanti record sono ancora indietro.
      onProcessQueueComplete?.call();
    }
  }

  Future<void> _attemptSyncIfOnline(String trigger) async {
    final results = await _connectivity.checkConnectivity();
    final hasNet = _hasNetwork(results);
    debugPrint(
      '[SyncOrchestrator] $trigger: hasNetwork=$hasNet isSyncing=$_isSyncing',
    );
    if (hasNet) {
      await _attemptSync(trigger);
    }
  }

  Future<void> _attemptSync(
    String trigger, {
    bool resetRetries = false,
  }) async {
    if (_isSyncing) {
      debugPrint('[SyncOrchestrator] $trigger: skipped (already syncing)');
      return;
    }
    _isSyncing = true;
    onSyncStarted?.call();
    _monitoring.logBreadcrumb(
      'Avvio sincronizzazione. Trigger: $trigger',
      category: 'sync',
      data: {'trigger': trigger},
    );
    try {
      if (resetRetries) await _syncService.resetAllSyncRetries();
      await _syncService.processQueue();
    } catch (e, st) {
      debugPrint('[SyncOrchestrator] Sync failed: $e');
      debugPrint('[SyncOrchestrator] Stack trace:\n$st');
      _monitoring.captureException(
        e,
        stackTrace: st,
        tags: {'operation': 'orchestrator_processQueue', 'trigger': trigger},
      );
    } finally {
      _isSyncing = false;
      onProcessQueueComplete?.call();
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
