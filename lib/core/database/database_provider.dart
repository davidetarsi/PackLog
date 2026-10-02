import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database.dart';
import 'encryption/db_passphrase_service.dart';

part 'database_provider.g.dart';

/// Provider singleton per il database Drift.
///
/// [AppDatabase] viene creato in modo sincrono; la passphrase SQLCipher è
/// letta lazily da [DbPassphraseService] al momento della prima connessione.
///
/// PRECONDIZIONE: [EncryptionMigrationService.ensureMigrated] deve essere
/// stato chiamato prima che qualsiasi query raggiunga il DB — garantito da
/// [_initializePersistence] in `bootstrap.dart` che gira prima di qualsiasi
/// consumer Riverpod.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase(DbPassphraseService());

  ref.onDispose(() {
    database.close();
  });

  return database;
}
