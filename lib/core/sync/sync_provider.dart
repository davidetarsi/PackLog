import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../analytics/core_analytics_service.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../database/database_provider.dart';
import '../monitoring/monitoring_service.dart';
import 'supabase_repository.dart';
import 'sync_orchestrator.dart';
import 'sync_run_state.dart';
import 'sync_service.dart';
import 'tombstone_config_service.dart';

part 'sync_provider.g.dart';

/// Chiave SharedPreferences che ricorda l'ultimo userId loggato sul device.
/// Se al login successivo il userId è diverso → cambio account, wipe locale.
@visibleForTesting
const kLastKnownUserIdKey = 'sync.last_known_user_id';
@visibleForTesting
String pendingRestoreUserKey(String userId) => 'sync.pending_full_pull.$userId';

@visibleForTesting
({bool changed, String? userId}) authSessionReplacement(
  AuthState? previous,
  AuthState next,
) {
  if (next case Authenticated(:final userId)) {
    final previousUserId = switch (previous) {
      Authenticated(:final userId) => userId,
      _ => null,
    };
    return (changed: previousUserId != userId, userId: userId);
  }
  return (changed: previous is Authenticated, userId: null);
}

/// Prepara i dati locali all'interno del cambio sessione atomico. Il callback
/// [replaceSession] invalida subito il proprietario precedente e attende i
/// commit locali già avviati prima di eseguire questa preparazione.
@visibleForTesting
Future<void> handleAuthenticatedUser({
  required String userId,
  required SyncService syncService,
  required Future<void> Function(Future<bool> Function() prepareLocalData)
  replaceSession,
  required Future<SharedPreferences> Function() getPreferences,
}) {
  return replaceSession(() async {
    final prefs = await getPreferences();
    final last = prefs.getString(kLastKnownUserIdKey);
    var wiped = false;
    if (last == null || last != userId) {
      if (!await prefs.setBool(pendingRestoreUserKey(userId), true)) {
        throw StateError('Could not persist pending restore marker');
      }
      if (last != null) {
        debugPrint('[sync_provider] account switch detected: $last → $userId');
        await syncService.wipeAllUserData();
        wiped = true;
      }
    }
    if (!await prefs.setString(kLastKnownUserIdKey, userId)) {
      throw StateError('Could not persist current sync owner');
    }
    return wiped || (prefs.getBool(pendingRestoreUserKey(userId)) ?? false);
  });
}

/// Incrementato ogni volta che un fullPull completa con successo.
/// I notifier dei dati (Houses, Items, Trips) lo watchano per ricostruirsi
/// e mostrare i nuovi record scaricati da Supabase senza richiedere un refresh manuale.
@Riverpod(keepAlive: true)
class SyncTrigger extends _$SyncTrigger {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Unica proiezione Riverpod dello stato runtime pubblicato dall'orchestrator.
@Riverpod(keepAlive: true)
Stream<SyncRunState> syncRunState(Ref ref) =>
    ref.watch(syncOrchestratorProvider).states;

/// Alias compatibile e read-only: la schermata case mostra loading durante pull.
@Riverpod(keepAlive: true)
bool syncing(Ref ref) {
  final state =
      ref.watch(syncRunStateProvider).valueOrNull ??
      ref.read(syncOrchestratorProvider).state;
  return (state is SyncRunning && state.operation == SyncOperationKind.pull) ||
      state is SyncSwitchingSession;
}

/// Alias compatibile e read-only usato dalla tile di stato sync.
@Riverpod(keepAlive: true)
bool syncNeedsRestore(Ref ref) {
  ref.watch(syncRunStateProvider);
  return ref.read(syncOrchestratorProvider).needsRestore;
}

@Riverpod(keepAlive: true)
bool syncPushInProgress(Ref ref) {
  final state =
      ref.watch(syncRunStateProvider).valueOrNull ??
      ref.read(syncOrchestratorProvider).state;
  return state is SyncRunning && state.operation == SyncOperationKind.push;
}

@Riverpod(keepAlive: true)
SupabaseRepository supabaseRepository(Ref ref) {
  return SupabaseRepository(Supabase.instance.client);
}

@Riverpod(keepAlive: true)
TombstoneConfigService tombstoneConfigService(Ref ref) {
  return TombstoneConfigService(Supabase.instance.client);
}

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final db = ref.read(appDatabaseProvider);
  return SyncService(
    housesDao: db.housesDao,
    itemsDao: db.itemsDao,
    spacesDao: db.spacesDao,
    luggagesDao: db.luggagesDao,
    kitsDao: db.kitsDao,
    kitItemsDao: db.kitItemsDao,
    tripsDao: db.tripsDao,
    suitcaseEditsDao: db.suitcaseEditsDao,
    remote: ref.read(supabaseRepositoryProvider),
    monitoring: ref.read(monitoringServiceProvider),
    tombstoneConfig: ref.read(tombstoneConfigServiceProvider),
    analytics: ref.read(coreAnalyticsServiceProvider),
  );
}

@Riverpod(keepAlive: true)
SyncOrchestrator syncOrchestrator(Ref ref) {
  final orchestrator = SyncOrchestrator(
    ref.read(syncServiceProvider),
    ref.read(monitoringServiceProvider),
  );
  orchestrator.init();

  // Il trigger resta success-only: sincronizza i notifier solo dopo pull ok.
  orchestrator.onFullPullComplete = () {
    ref.read(syncTriggerProvider.notifier).increment();
    final userId = orchestrator.currentUserId;
    final epoch = orchestrator.sessionEpoch;
    final monitoring = ref.read(monitoringServiceProvider);
    if (userId != null) {
      unawaited(
        SharedPreferences.getInstance()
            .then((prefs) async {
              if (orchestrator.currentUserId != userId ||
                  orchestrator.sessionEpoch != epoch) {
                return;
              }
              await prefs.remove(pendingRestoreUserKey(userId));
            })
            .catchError((Object error, StackTrace stackTrace) {
              // Pull is already committed; cleanup failure keeps restore pending
              // for the next launch and must not become an unhandled async error.
              if (orchestrator.currentUserId == userId &&
                  orchestrator.sessionEpoch == epoch) {
                monitoring.captureException(
                  error,
                  stackTrace: stackTrace,
                  tags: const {'operation': 'sync_restore_marker_cleanup'},
                );
              }
            }),
      );
    }
  };

  // Quando un push parte davvero invalida il counter pending, evitando valori
  // cacheati mentre la coda viene processata.
  orchestrator.onSyncStarted = () {
    ref.invalidate(pendingChangesCountProvider);
  };

  // Quando processQueue termina (successo o errore) invalida entrambi i
  // counter così il tile mostra il dato fresco.
  orchestrator.onProcessQueueComplete = () {
    ref.invalidate(pendingChangesCountProvider);
    ref.invalidate(totalUnsyncedCountProvider);
  };

  void dispatch(String userId) {
    unawaited(
      handleAuthenticatedUser(
        userId: userId,
        syncService: ref.read(syncServiceProvider),
        replaceSession: (prepare) => orchestrator.replaceSession(
          userId,
          prepareLocalData: () async {
            final needsRestore = await prepare();
            if (needsRestore) {
              ref.read(syncTriggerProvider.notifier).increment();
            }
            return needsRestore;
          },
        ),
        getPreferences: SharedPreferences.getInstance,
      ),
    );
  }

  // Full pull all'avvio: copre sia la sessione persistita (read immediato)
  // sia il login fresco (listen sulla transizione Unauth→Auth).
  final initialAuth = ref.read(authNotifierProvider);
  if (initialAuth is Authenticated) {
    dispatch(initialAuth.userId);
  }

  ref.listen<AuthState>(authNotifierProvider, (prev, next) {
    final replacement = authSessionReplacement(prev, next);
    if (!replacement.changed) return;
    final userId = replacement.userId;
    if (userId != null) {
      dispatch(userId);
    } else {
      unawaited(
        orchestrator.replaceSession(null, prepareLocalData: () async => false),
      );
    }
  });

  ref.onDispose(orchestrator.dispose);
  return orchestrator;
}

/// Conta delle modifiche locali ancora da pushare al cloud.
///
/// Invalidato automaticamente:
/// - dopo ogni `processQueue` (push), success o failure — via
///   `SyncOrchestrator.onProcessQueueComplete`;
/// - quando l'utente preme "Riprova" sulla `SyncStatusTile`.
///
/// Watcha anche [syncTriggerProvider] per ri-eseguirsi dopo un fullPull
/// (pull può aver portato nuovi record locali in stato `synced`, riducendo
/// il conteggio).
@riverpod
Future<int> pendingChangesCount(Ref ref) async {
  ref.watch(syncTriggerProvider);
  return ref.read(syncServiceProvider).countPendingChanges();
}

/// Conta tutti i record locali con syncStatus != synced, inclusi quelli stuck
/// in retry backoff o con retry count esaurito.
///
/// Usato dalla [SyncStatusTile] per decidere se mostrare il pulsante
/// "Sincronizza ora": rimane visibile finché esistono dati non su Supabase,
/// anche quando [pendingChangesCountProvider] restituisce 0 per effetto
/// del filtro di backoff.
@riverpod
Future<int> totalUnsyncedCount(Ref ref) async {
  ref.watch(syncTriggerProvider);
  return ref.read(syncServiceProvider).countAllUnsyncedChanges();
}

/// Breakdown per-entità delle modifiche pending, per il dialog di dettaglio
/// aperto dal tap sulla [SyncStatusTile]. Dato transitorio, scope del dialog:
/// **non** keepAlive (a differenza dei data provider di dominio come
/// `itemNotifierProvider`) — nessun altro screen dipende da questo stato.
@riverpod
Future<List<SyncEntityStatus>> syncUnsyncedBreakdown(Ref ref) {
  return ref.read(syncServiceProvider).getUnsyncedBreakdown();
}
