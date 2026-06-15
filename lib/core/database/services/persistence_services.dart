import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database_provider.dart';
import 'database_service.dart';
import 'data_integrity_service.dart';

part 'persistence_services.g.dart';

/// Provider per il DatabaseService.
@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return DatabaseService(database);
}

// Nota: `backupService` è dichiarato esclusivamente in
// [backup_controller.dart]. Una precedente versione duplicava il provider
// qui causando due istanze separate dello stesso service a seconda
// dell'import. Rimosso per ripristinare "un solo provider per service"
// (CLAUDE.md). Il backup locale è in deprecazione: quando il flow verrà
// dismesso del tutto, anche [backup_controller] potrà sparire.

/// Provider per il DataIntegrityService.
@Riverpod(keepAlive: true)
DataIntegrityService dataIntegrityService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return DataIntegrityService(database);
}
