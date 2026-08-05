import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/consent/consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConsentService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ConsentService();
  });

  group('fail-closed', () {
    test('senza load() il consenso è assente', () {
      // Invariante centrale del gate: prima dell'idratazione non si trasmette.
      expect(service.hasConsent, isFalse);
    });

    test('dopo load() su storage vuoto resta assente', () async {
      await service.load();
      expect(service.hasConsent, isFalse);
      expect(service.givenAt, isNull);
      expect(service.needsRemoteFlush, isFalse);
    });

    test('load() con storage illeggibile non concede il consenso', () async {
      // DateTime.tryParse fallisce e restituisce null: non deve tradursi in
      // un consenso valido.
      SharedPreferences.setMockInitialValues({
        'consent_given_at': 'non-una-data',
      });
      await service.load();
      expect(service.hasConsent, isFalse);
    });
  });

  group('record', () {
    test('registra consenso, versione e necessità di flush', () async {
      await service.load();
      await service.record(policyVersion: '2026-07-30');

      expect(service.hasConsent, isTrue);
      expect(service.policyVersion, '2026-07-30');
      expect(service.givenAt, isNotNull);
      expect(service.needsRemoteFlush, isTrue);
    });

    test('il consenso è visibile prima ancora della persistenza', () async {
      await service.load();
      // Nessun await: il gate legge in modo sincrono, e login_screen emette
      // `consent_given` subito dopo aver chiamato record().
      unawaited(service.record(policyVersion: 'v1'));
      expect(service.hasConsent, isTrue);
    });

    test('first write wins: non sovrascrive un consenso già dato', () async {
      await service.load();
      await service.record(policyVersion: 'v1');
      final primo = service.givenAt;

      await service.record(policyVersion: 'v2');

      expect(service.givenAt, primo, reason: 'la data non deve spostarsi');
      expect(service.policyVersion, 'v1');
    });

    test('sopravvive al riavvio', () async {
      await service.load();
      await service.record(policyVersion: '2026-07-30');
      final atteso = service.givenAt;

      final dopoRiavvio = ConsentService();
      await dopoRiavvio.load();

      expect(dopoRiavvio.hasConsent, isTrue);
      expect(dopoRiavvio.policyVersion, '2026-07-30');
      expect(dopoRiavvio.givenAt, atteso);
      expect(dopoRiavvio.needsRemoteFlush, isTrue);
    });
  });

  group('flush remoto', () {
    test('markSyncedRemote spegne la necessità di flush', () async {
      await service.load();
      await service.record(policyVersion: 'v1');
      await service.markSyncedRemote();

      expect(service.needsRemoteFlush, isFalse);
      expect(service.hasConsent, isTrue, reason: 'il consenso resta valido');
    });

    test('lo stato sincronizzato persiste al riavvio', () async {
      await service.load();
      await service.record(policyVersion: 'v1');
      await service.markSyncedRemote();

      final dopoRiavvio = ConsentService();
      await dopoRiavvio.load();

      expect(dopoRiavvio.needsRemoteFlush, isFalse);
    });
  });

  group('revoca', () {
    test('despuntare prima del flush cancella il consenso', () async {
      await service.load();
      await service.record(policyVersion: 'v1');
      await service.revokeLocal();

      expect(service.hasConsent, isFalse);
      expect(service.givenAt, isNull);
      expect(service.policyVersion, isNull);
    });

    test('la revoca è persistita, non solo in memoria', () async {
      await service.load();
      await service.record(policyVersion: 'v1');
      await service.revokeLocal();

      final dopoRiavvio = ConsentService();
      await dopoRiavvio.load();

      expect(dopoRiavvio.hasConsent, isFalse);
    });

    test('dopo il flush remoto la revoca locale è inefficace', () async {
      // Una volta che il consenso è agli atti su Supabase, cancellarlo in
      // locale creerebbe una divergenza silenziosa col registro remoto.
      await service.load();
      await service.record(policyVersion: 'v1');
      await service.markSyncedRemote();

      await service.revokeLocal();

      expect(service.hasConsent, isTrue);
    });
  });
}

/// Equivalente locale di `dart:async`.unawaited, per non importare l'intera
/// libreria in un file di test.
void unawaited(Future<void> future) {}
