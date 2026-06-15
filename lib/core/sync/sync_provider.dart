import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../database/database_provider.dart';
import '../monitoring/monitoring_service.dart';
import 'supabase_repository.dart';
import 'sync_orchestrator.dart';
import 'sync_service.dart';
import 'tombstone_config_service.dart';

part 'sync_provider.g.dart';

/// Chiave SharedPreferences che ricorda l'ultimo userId loggato sul device.
/// Se al login successivo il userId è diverso → cambio account, wipe locale.
@visibleForTesting
const kLastKnownUserIdKey = 'sync.last_known_user_id';

/// Gestisce un evento di autenticazione: rileva un cambio di account
/// (userId diverso dal precedente memorizzato in [SharedPreferences]) e
/// in quel caso ripulisce il DB locale prima di scaricare i dati del nuovo
/// utente. Idempotente: stesso userId → nessun wipe, solo fullPull.
@visibleForTesting
Future<void> handleAuthenticatedUser({
  required String userId,
  required SyncService syncService,
  required void Function(String userId) requestFullPull,
  required SharedPreferences prefs,
}) async {
  final last = prefs.getString(kLastKnownUserIdKey);
  if (last != null && last != userId) {
    debugPrint('[sync_provider] account switch detected: $last → $userId');
    await syncService.wipeAllUserData();
  }
  await prefs.setString(kLastKnownUserIdKey, userId);
  requestFullPull(userId);
}

/// Incrementato ogni volta che un fullPull completa con successo.
/// I notifier dei dati (Houses, Items, Trips) lo watchano per ricostruirsi
/// e mostrare i nuovi record scaricati da Supabase senza richiedere un refresh manuale.
final syncTriggerProvider = StateProvider<int>((ref) => 0);

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
    tripsDao: db.tripsDao,
    remote: ref.read(supabaseRepositoryProvider),
    monitoring: ref.read(monitoringServiceProvider),
    tombstoneConfig: ref.read(tombstoneConfigServiceProvider),
  );
}

@Riverpod(keepAlive: true)
SyncOrchestrator syncOrchestrator(Ref ref) {
  final orchestrator = SyncOrchestrator(
    ref.read(syncServiceProvider),
    ref.read(monitoringServiceProvider),
  );
  orchestrator.init();

  // Quando fullPull completa, incrementa il trigger → i notifier si ricostruiscono.
  orchestrator.onFullPullComplete = () {
    ref.read(syncTriggerProvider.notifier).state++;
  };

  // Quando un push parte davvero (mutex acquisito), invalida subito il counter
  // così la `SyncStatusTile` mostra lo stato di caricamento invece di un
  // valore cacheato stale. Il provider si aggiorna di nuovo a fine push via
  // onProcessQueueComplete.
  orchestrator.onSyncStarted = () {
    ref.invalidate(pendingChangesCountProvider);
  };

  // Quando processQueue (push) termina — successo o errore — invalida il
  // counter dei record pending così la `SyncStatusTile` in profilo mostra
  // il dato fresco. Non tocca `syncTriggerProvider` per evitare rebuild a
  // cascata dei notifier dei dati (che dipendono solo dal fullPull).
  orchestrator.onProcessQueueComplete = () {
    ref.invalidate(pendingChangesCountProvider);
  };

  Future<void> dispatch(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await handleAuthenticatedUser(
      userId: userId,
      syncService: ref.read(syncServiceProvider),
      requestFullPull: orchestrator.requestFullPull,
      prefs: prefs,
    );
  }

  // Full pull all'avvio: copre sia la sessione persistita (read immediato)
  // sia il login fresco (listen sulla transizione Unauth→Auth).
  final initialAuth = ref.read(authNotifierProvider);
  if (initialAuth is Authenticated) {
    dispatch(initialAuth.userId);
  }

  ref.listen<AuthState>(authNotifierProvider, (prev, next) {
    if (next is Authenticated && prev is! Authenticated) {
      dispatch(next.userId);
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
