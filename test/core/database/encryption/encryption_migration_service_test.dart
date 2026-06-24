import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/encryption/db_passphrase_service.dart';
import 'package:pack_log/core/database/encryption/encryption_exceptions.dart';
import 'package:pack_log/core/database/encryption/encryption_migration_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class _StubPassphraseService extends DbPassphraseService {
  _StubPassphraseService(this._value) : super();
  String? _value;
  @override
  Future<String> getOrCreate() async {
    _value ??= 'a' * 64;
    return _value!;
  }

  @override
  Future<bool> exists() async => _value != null;
}

class _FailingPassphraseService extends DbPassphraseService {
  _FailingPassphraseService() : super();
  @override
  Future<String> getOrCreate() async {
    throw const PassphraseUnavailableException('mock');
  }
}

/// Verifica se SQLCipher è disponibile nel test runner corrente.
/// Su host macOS/Linux `flutter test` usa il sistema sqlite3 (non SQLCipher),
/// quindi `ATTACH ... KEY` e `sqlcipher_export` non sono disponibili.
/// Su device/simulator il plugin carica SQLCipher e questi test passano.
bool _sqlcipherAvailable() {
  final db = sqlite3.openInMemory();
  try {
    db.execute('SELECT sqlcipher_version();');
    return true;
  } catch (_) {
    return false;
  } finally {
    db.dispose();
  }
}

const _skipNoSqlcipher =
    'SQLCipher not available in host runner — run on device/simulator';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late String plainPath;
  late String encryptedPath;
  late _StubPassphraseService passService;
  late EncryptionMigrationService service;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('enc_mig_');
    plainPath = p.join(tmpDir.path, 'stuff_tracker.db');
    encryptedPath = p.join(tmpDir.path, 'stuff_tracker.db.encrypting');
    passService = _StubPassphraseService(null);
    service = EncryptionMigrationService(
      passphraseService: passService,
      databasePath: plainPath,
      stagingPath: encryptedPath,
    );
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  /// Crea un DB plaintext con N righe nella tabella `t`.
  void seedPlaintextDb(int rows) {
    final db = sqlite3.open(plainPath);
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT);');
    for (var i = 0; i < rows; i++) {
      db.execute('INSERT INTO t (name) VALUES (?)', ['row-$i']);
    }
    db.dispose();
  }

  /// Conta righe in `t`, decifrando con [pass].
  int countWithKey(String path, String pass) {
    final db = sqlite3.open(path);
    db.execute("PRAGMA key = \"x'$pass'\";");
    final r = db.select('SELECT COUNT(*) AS c FROM t');
    final c = r.first['c'] as int;
    db.dispose();
    return c;
  }

  test('fresh install: no plain, no encrypted → no-op + passphrase created',
      () async {
    await service.ensureMigrated();
    expect(File(plainPath).existsSync(), false);
    expect(await passService.exists(), true);
  });

  test('already migrated: plain absent → no-op', () async {
    // Simula uno stato già migrato creando solo la passphrase e nessun file.
    await passService.getOrCreate();
    await service.ensureMigrated();
    expect(File(plainPath).existsSync(), false);
  });

  test(
    'migration: plain present → moves to encrypted, plain deleted',
    () async {
      seedPlaintextDb(3);
      expect(File(plainPath).existsSync(), true);

      await service.ensureMigrated();

      expect(File(plainPath).existsSync(), true);
      final pass = await passService.getOrCreate();
      expect(countWithKey(plainPath, pass), 3);
      expect(File('$plainPath.pre-encrypt-backup').existsSync(), false);
      expect(File(encryptedPath).existsSync(), false);
    },
    skip: _sqlcipherAvailable() ? null : _skipNoSqlcipher,
  );

  test(
    'dirty state recovery: stale staging file → discarded, retry',
    () async {
      seedPlaintextDb(2);
      await File(encryptedPath).writeAsString('garbage');

      await service.ensureMigrated();

      final pass = await passService.getOrCreate();
      expect(countWithKey(plainPath, pass), 2);
      expect(File(encryptedPath).existsSync(), false);
    },
    skip: _sqlcipherAvailable() ? null : _skipNoSqlcipher,
  );

  test('passphrase failure: throws EncryptionMigrationException', () async {
    seedPlaintextDb(1);
    final failingService = EncryptionMigrationService(
      passphraseService: _FailingPassphraseService(),
      databasePath: plainPath,
      stagingPath: encryptedPath,
    );
    expect(
      failingService.ensureMigrated(),
      throwsA(isA<EncryptionMigrationException>()),
    );
  });
}
