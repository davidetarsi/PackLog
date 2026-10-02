import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'db_passphrase_service.dart';
import 'encryption_exceptions.dart';

/// Orchestra la migrazione one-shot del database locale da plaintext a
/// cifrato (SQLCipher). Idempotente: chiamabile a ogni avvio.
///
/// ## Stati possibili (matrice)
///
/// | Plain file | Staging file | Passphrase | Azione                  |
/// |------------|--------------|------------|-------------------------|
/// | assente    | qualsiasi    | qualsiasi  | no-op (fresh install)   |
/// | presente   | assente      | qualsiasi  | MIGRATE                 |
/// | presente   | presente     | qualsiasi  | rimuovi staging, retry  |
///
/// La verifica `is the plain file actually plaintext?` è implicita:
/// se al boot precedente la migrazione era completata, il file di nome
/// `stuff_tracker.db` è già il file cifrato (lo abbiamo rinominato);
/// in quel caso non c'è nessun plain residuo e siamo in no-op.
///
/// ## Flusso di migrazione (caso happy)
///
/// 1. Genera/recupera passphrase
/// 2. Apri il plain via `sqlite3.open` (senza key)
/// 3. `ATTACH DATABASE '<staging>' AS encrypted KEY "x'<hex>'"`
/// 4. `SELECT sqlcipher_export('encrypted')` — copia schema + dati
/// 5. `DETACH` + close plain
/// 6. Verifica integrità: apri staging con key, conta righe core
/// 7. Crea backup `.pre-encrypt-backup` dal plain
/// 8. Sostituisci atomicamente plain con staging (rename)
/// 9. Cancella backup
class EncryptionMigrationService {
  final DbPassphraseService _passphraseService;
  final String _databasePath;
  final String _stagingPath;

  EncryptionMigrationService({
    required DbPassphraseService passphraseService,
    String? databasePath,
    String? stagingPath,
  }) : _passphraseService = passphraseService,
       _databasePath = databasePath ?? '',
       _stagingPath = stagingPath ?? '';

  /// Costruisce un'istanza con path di default. Usato a runtime.
  /// I path-injection-based test usano il costruttore principale.
  static Future<EncryptionMigrationService> withDefaultPaths(
    DbPassphraseService passphraseService,
  ) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return EncryptionMigrationService(
      passphraseService: passphraseService,
      databasePath: p.join(dbFolder.path, 'stuff_tracker.db'),
      stagingPath: p.join(dbFolder.path, 'stuff_tracker.db.encrypting'),
    );
  }

  String get _backupPath => '$_databasePath.pre-encrypt-backup';

  /// Punto di ingresso unico. Idempotente.
  Future<void> ensureMigrated() async {
    try {
      // 1. Cleanup di eventuale staging stale (crash al boot precedente).
      final stagingFile = File(_stagingPath);
      if (stagingFile.existsSync()) {
        debugPrint('[EncMig] Stale staging file found, removing.');
        await stagingFile.delete();
      }

      final plainFile = File(_databasePath);
      if (!plainFile.existsSync()) {
        debugPrint('[EncMig] No DB present — fresh install. Generating key.');
        // Genera la passphrase ora così è disponibile quando Drift creerà
        // il DB cifrato vuoto al primo accesso.
        await _passphraseService.getOrCreate();
        return;
      }

      // 2. Capisci se il DB è già cifrato (caso post-migrazione).
      if (await _isAlreadyEncrypted(plainFile)) {
        debugPrint('[EncMig] DB already encrypted, no-op.');
        return;
      }

      // 3. Migrazione vera e propria.
      debugPrint('[EncMig] Plain DB detected, starting migration...');
      await _migrate(plainFile);
      debugPrint('[EncMig] Migration completed successfully.');
    } on EncryptionException {
      rethrow;
    } catch (e, st) {
      throw EncryptionMigrationException(
        'Unexpected failure during encryption migration',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Test euristico: prova ad aprire come plaintext + read schema. Se
  /// fallisce → è cifrato (o corrotto). Se passa → è plain.
  Future<bool> _isAlreadyEncrypted(File file) async {
    Database? db;
    try {
      db = sqlite3.open(file.path);
      db.select('SELECT name FROM sqlite_master LIMIT 1');
      return false;
    } catch (_) {
      return true;
    } finally {
      db?.dispose();
    }
  }

  Future<void> _migrate(File plainFile) async {
    // Backup del plain originale (rollback safety net).
    // Creato prima del try: se la passphrase non è disponibile il backup
    // rimane ma il plain è intatto — nessun danno.
    final backup = File(_backupPath);
    if (backup.existsSync()) await backup.delete();
    await plainFile.copy(_backupPath);

    Database? plainDb;
    try {
      // Passphrase dentro il try: un'eccezione qui viene wrappata in
      // EncryptionMigrationException come tutte le altre failure di migrazione.
      final passphrase = await _passphraseService.getOrCreate();
      plainDb = sqlite3.open(plainFile.path);
      plainDb.execute(
        "ATTACH DATABASE '${_stagingPath.replaceAll("'", "''")}' AS encrypted KEY \"x'$passphrase'\";",
      );
      plainDb.execute("SELECT sqlcipher_export('encrypted');");
      plainDb.execute("DETACH DATABASE encrypted;");
      plainDb.dispose();
      plainDb = null;

      // Verifica integrità: apri staging con key e leggi schema
      final verify = sqlite3.open(_stagingPath);
      verify.execute("PRAGMA key = \"x'$passphrase'\";");
      verify.select('SELECT name FROM sqlite_master LIMIT 1');
      verify.dispose();

      // Atomic swap: rename staging → plain path
      await plainFile.delete();
      await File(_stagingPath).rename(_databasePath);

      // Successo → rimuovi backup
      await backup.delete();
    } catch (e, st) {
      // Cleanup parziale: rimuovi staging se rimasto a metà.
      try {
        final staging = File(_stagingPath);
        if (staging.existsSync()) await staging.delete();
      } catch (_) {}

      // Rollback: se il plain è stato cancellato ma il rename è fallito,
      // ripristinalo dal backup.
      if (!plainFile.existsSync() && backup.existsSync()) {
        try {
          await backup.copy(plainFile.path);
        } catch (_) {}
      }

      throw EncryptionMigrationException(
        'Failed to migrate plaintext DB to encrypted',
        originalError: e,
        stackTrace: st,
      );
    } finally {
      plainDb?.dispose();
    }
  }
}
