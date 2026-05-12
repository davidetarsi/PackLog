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

  SyncOrchestrator(
    this._syncService,
    this._monitoring, {
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
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

  Future<void> _attemptSyncIfOnline(String trigger) async {
    final results = await _connectivity.checkConnectivity();
    final hasNet = _hasNetwork(results);
    debugPrint('[SyncOrchestrator] $trigger: hasNetwork=$hasNet isSyncing=$_isSyncing');
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
