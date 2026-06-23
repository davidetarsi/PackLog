import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/encryption/db_passphrase_service.dart';
import 'package:pack_log/core/database/encryption/encryption_exceptions.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSecureStorage mock;
  late DbPassphraseService service;

  setUp(() {
    mock = _MockSecureStorage();
    service = DbPassphraseService(secure: mock);
    when(() => mock.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
  });

  test('first call generates a new 64-hex-char passphrase and writes it',
      () async {
    final pass = await service.getOrCreate();

    expect(pass, isA<String>());
    expect(pass.length, 64, reason: '32 bytes hex-encoded → 64 char');
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(pass), true);
    verify(() => mock.write(
          key: DbPassphraseService.kStorageKey,
          value: pass,
        )).called(1);
  });

  test('subsequent calls return the existing passphrase, no write', () async {
    const existing =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    when(() => mock.read(key: DbPassphraseService.kStorageKey))
        .thenAnswer((_) async => existing);

    final pass = await service.getOrCreate();

    expect(pass, existing);
    verifyNever(() => mock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ));
  });

  test('two different services generate different passphrases', () async {
    final m1 = _MockSecureStorage();
    final m2 = _MockSecureStorage();
    for (final m in [m1, m2]) {
      when(() => m.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      when(() => m.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
    }
    final s1 = DbPassphraseService(secure: m1);
    final s2 = DbPassphraseService(secure: m2);
    final p1 = await s1.getOrCreate();
    final p2 = await s2.getOrCreate();
    expect(p1, isNot(equals(p2)),
        reason: 'Random generator must produce different values');
  });

  test('throws PassphraseUnavailableException on read failure', () async {
    when(() => mock.read(key: any(named: 'key')))
        .thenThrow(Exception('keystore broken'));

    expect(
      () => service.getOrCreate(),
      throwsA(isA<PassphraseUnavailableException>()),
    );
  });

  test('throws PassphraseUnavailableException on write failure', () async {
    when(() => mock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenThrow(Exception('write denied'));

    expect(
      () => service.getOrCreate(),
      throwsA(isA<PassphraseUnavailableException>()),
    );
  });

  test('exists() returns false initially', () async {
    expect(await service.exists(), false);
  });

  test('exists() returns true after getOrCreate', () async {
    const existing =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    when(() => mock.read(key: DbPassphraseService.kStorageKey))
        .thenAnswer((_) async => existing);
    expect(await service.exists(), true);
  });
}
