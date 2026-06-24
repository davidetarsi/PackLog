import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

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
  late String dbPath;
  final passphrase = 'a' * 64;
  final wrongPassphrase = 'b' * 64;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('enc_rt_');
    dbPath = p.join(tmpDir.path, 'roundtrip.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  test(
    'write encrypted, close, reopen with correct passphrase → data intact',
    () {
      final db1 = sqlite3.open(dbPath);
      db1.execute("PRAGMA key = \"x'$passphrase'\";");
      db1.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT);');
      db1.execute("INSERT INTO t (name) VALUES ('hello');");
      db1.dispose();

      final db2 = sqlite3.open(dbPath);
      db2.execute("PRAGMA key = \"x'$passphrase'\";");
      final rows = db2.select('SELECT name FROM t');
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'hello');
      db2.dispose();
    },
    skip: _sqlcipherAvailable() ? null : _skipNoSqlcipher,
  );

  test(
    'write encrypted, reopen with wrong passphrase → query throws',
    () {
      final db1 = sqlite3.open(dbPath);
      db1.execute("PRAGMA key = \"x'$passphrase'\";");
      db1.execute('CREATE TABLE t (id INTEGER PRIMARY KEY);');
      db1.dispose();

      final db2 = sqlite3.open(dbPath);
      db2.execute("PRAGMA key = \"x'$wrongPassphrase'\";");
      expect(
        () => db2.select('SELECT * FROM t'),
        throwsA(isA<SqliteException>()),
      );
      db2.dispose();
    },
    skip: _sqlcipherAvailable() ? null : _skipNoSqlcipher,
  );

  test(
    'encrypted file header is NOT a SQLite plaintext header',
    () async {
      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA key = \"x'$passphrase'\";");
      db.execute('CREATE TABLE t (id INTEGER);');
      db.dispose();

      final bytes = await File(dbPath).readAsBytes();
      final header = String.fromCharCodes(bytes.sublist(0, 15));
      expect(header, isNot('SQLite format 3'),
          reason: 'Encrypted file must not start with the plaintext header');
    },
    skip: _sqlcipherAvailable() ? null : _skipNoSqlcipher,
  );
}
