import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database_provider.dart';
import 'database_service.dart';
import 'backup_service.dart';
import 'data_integrity_service.dart';

part 'persistence_services.g.dart';

/// Provider per il DatabaseService.
@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return DatabaseService(database);
}

/// Provider per il BackupService.
@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) {
  return BackupService();
}

/// Provider per il DataIntegrityService.
@Riverpod(keepAlive: true)
DataIntegrityService dataIntegrityService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return DataIntegrityService(database);
}
