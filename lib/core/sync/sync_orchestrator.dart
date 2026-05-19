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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Chiamato da [sync_provider] dopo ogni fullPull riuscito.
  /// Usato per notificare i notifier dei dati di rifetchare.
  void Function()? onFullPullComplete;

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
      _attemptSyncIfOnline('app_resume');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_hasNetwork(results)) {
      _attemptSync('connectivity_restored');
    }
  }

  /// Triggers sync after a local DB mutation (create/update/delete).
  /// Fire-and-forget: callers should not await this.
  void requestSync() {
    debugPrint('[SyncOrchestrator] requestSync called');
    _attemptSyncIfOnline('local_mutation');
  }

  /// Scarica tutti i record dell'utente da Supabase al DB locale.
  /// Chiamato ad ogni avvio quando l'utente risulta autenticato.
  /// Fire-and-forget: non blocca il chiamante.
  void requestFullPull(String userId) {
    _attemptFullPullIfOnline(userId);
  }

  Future<void> _attemptFullPullIfOnline(String userId) async {
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
    _monitoring.logBreadcrumb(
      'Avvio fullPull. userId: $userId',
      category: 'sync',
      data: {'userId': userId},
    );
    try {
      await _syncService.fullPull(userId);
      onFullPullComplete?.call();
    } catch (e, st) {
      debugPrint('[SyncOrchestrator] fullPull failed: $e');
      debugPrint('[SyncOrchestrator] Stack trace:\n$st');
    } finally {
      _isSyncing = false;
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

  Future<void> _attemptSync(String trigger) async {
    if (_isSyncing) {
      debugPrint('[SyncOrchestrator] $trigger: skipped (already syncing)');
      return;
    }
    _isSyncing = true;
    _monitoring.logBreadcrumb(
      'Avvio sincronizzazione automatica. Trigger: $trigger',
      category: 'sync',
      data: {'trigger': trigger},
    );
    try {
      await _syncService.processQueue();
    } catch (e, st) {
      debugPrint('[SyncOrchestrator] Sync failed: $e');
      debugPrint('[SyncOrchestrator] Stack trace:\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
