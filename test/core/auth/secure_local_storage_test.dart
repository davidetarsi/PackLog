// Unit test per `SecureLocalStorage`.
//
// Copre:
//   - persistSession / accessToken / hasAccessToken / removePersistedSession
//   - migrazione one-shot da SharedPreferences (utente già loggato con la
//     vecchia versione dell'app)
//   - idempotenza: se la migrazione è già stata eseguita non duplica/azzera
//   - tolleranza agli errori: una migrazione fallita non rompe l'app
//
// Per evitare la dipendenza dal plugin nativo `flutter_secure_storage`,
// usiamo un mock in-memory che implementa la stessa superficie di
// `read/write/delete` che `SecureLocalStorage` chiama.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/auth/secure_local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _kKey = 'sb-fake-project-auth-token';
const _kSessionJson =
    '{"access_token":"AAA","refresh_token":"BBB","expires_at":1234567890}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSecureStorage mockSecure;
  late SecureLocalStorage storage;

  setUp(() {
    mockSecure = _MockSecureStorage();
    storage = SecureLocalStorage(
      persistSessionKey: _kKey,
      secure: mockSecure,
    );

    when(() => mockSecure.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecure.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => mockSecure.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    SharedPreferences.setMockInitialValues({});
  });

  group('basic CRUD', () {
    test('persistSession scrive sul secure storage', () async {
      await storage.persistSession(_kSessionJson);
      verify(() => mockSecure.write(key: _kKey, value: _kSessionJson))
          .called(1);
    });

    test('accessToken legge dal secure storage', () async {
      when(() => mockSecure.read(key: _kKey))
          .thenAnswer((_) async => _kSessionJson);
      final token = await storage.accessToken();
      expect(token, _kSessionJson);
    });

    test('hasAccessToken: true se valore non-null e non-vuoto', () async {
      when(() => mockSecure.read(key: _kKey))
          .thenAnswer((_) async => _kSessionJson);
      expect(await storage.hasAccessToken(), true);
    });

    test('hasAccessToken: false se valore vuoto', () async {
      when(() => mockSecure.read(key: _kKey)).thenAnswer((_) async => '');
      expect(await storage.hasAccessToken(), false);
    });

    test('hasAccessToken: false se valore null', () async {
      // default già null dal setUp
      expect(await storage.hasAccessToken(), false);
    });

    test('removePersistedSession cancella la chiave', () async {
      await storage.removePersistedSession();
      verify(() => mockSecure.delete(key: _kKey)).called(1);
    });
  });

  group('migration da SharedPreferences', () {
    test(
      'copia la sessione legacy da SP a secure storage e cancella da SP',
      () async {
        SharedPreferences.setMockInitialValues({_kKey: _kSessionJson});

        await storage.initialize();

        // 1. Scritto su secure storage con il valore originale
        verify(() => mockSecure.write(key: _kKey, value: _kSessionJson))
            .called(1);

        // 2. Rimosso da SP — la chiave non c'è più
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(_kKey), false);
      },
    );

    test('non migra se secure storage ha già la chiave (idempotenza)',
        () async {
      when(() => mockSecure.read(key: _kKey))
          .thenAnswer((_) async => _kSessionJson);
      SharedPreferences.setMockInitialValues({_kKey: 'STALE_LEGACY'});

      await storage.initialize();

      // Mai scritto: la migrazione è skip
      verifyNever(() => mockSecure.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
      // E NON ha rimosso da SP (sarebbe ok ma non necessario al test)
    });

    test('no-op se nessuna sessione legacy in SP', () async {
      // SP vuoto (default del setUp), secure storage vuoto
      await storage.initialize();

      verifyNever(() => mockSecure.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
    });

    test('errore del secure storage durante la migrazione non rilancia',
        () async {
      SharedPreferences.setMockInitialValues({_kKey: _kSessionJson});
      when(() => mockSecure.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenThrow(Exception('keystore broken'));

      // Non deve sollevare: vogliamo che l'app parta comunque (l'utente
      // farà relogin).
      await expectLater(storage.initialize(), completes);
    });
  });
}
