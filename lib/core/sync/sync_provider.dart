import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

  // Full pull all'avvio: copre sia la sessione persistita (read immediato)
  // sia il login fresco (listen sulla transizione Unauth→Auth).
  final initialAuth = ref.read(authNotifierProvider);
  if (initialAuth is Authenticated) {
    orchestrator.requestFullPull(initialAuth.userId);
  }

  ref.listen<AuthState>(authNotifierProvider, (prev, next) {
    if (next is Authenticated && prev is! Authenticated) {
      orchestrator.requestFullPull(next.userId);
    }
  });

  ref.onDispose(orchestrator.dispose);
  return orchestrator;
}
