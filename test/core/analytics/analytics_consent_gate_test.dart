import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/consent/consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Il gate del consenso in [AppAnalyticsService].
///
/// Regressione coperta: prima di questo gate l'app trasmetteva ad Amplitude e
/// a tgram gli eventi delle tre schermate di onboarding e della schermata di
/// login — tutti emessi prima che l'utente accettasse privacy policy e
/// termini.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'senza ConsentService il gate è aperto (percorso dei test esistenti)',
    () {
      expect(AppAnalyticsService(null).mayTransmit, isTrue);
    },
  );

  test('ConsentService non idratato blocca: fail-closed', () {
    // Nessun load(): è la finestra fra l'avvio dell'app e l'idratazione.
    final service = AppAnalyticsService(null, consent: ConsentService());
    expect(service.mayTransmit, isFalse);
  });

  test('idratato ma senza consenso blocca', () async {
    final consent = ConsentService();
    await consent.load();

    expect(AppAnalyticsService(null, consent: consent).mayTransmit, isFalse);
  });

  test('dopo il consenso trasmette', () async {
    final consent = ConsentService();
    await consent.load();
    await consent.record(policyVersion: '2026-07-30');

    expect(AppAnalyticsService(null, consent: consent).mayTransmit, isTrue);
  });

  test('la revoca richiude il gate', () async {
    final consent = ConsentService();
    await consent.load();
    await consent.record(policyVersion: '2026-07-30');
    await consent.revokeLocal();

    expect(AppAnalyticsService(null, consent: consent).mayTransmit, isFalse);
  });

  test('un consenso già su disco apre il gate all\'avvio successivo', () async {
    SharedPreferences.setMockInitialValues({
      'consent_given_at': DateTime.utc(2026, 7, 30).toIso8601String(),
      'consent_policy_version': '2026-07-30',
      'consent_synced_remote': true,
    });
    final consent = ConsentService();
    await consent.load();

    expect(AppAnalyticsService(null, consent: consent).mayTransmit, isTrue);
  });

  test('logEvent senza consenso non solleva eccezioni', () async {
    final service = AppAnalyticsService(null, consent: ConsentService());
    // Percorso caldo: deve uscire in silenzio, non rompere il chiamante.
    await expectLater(service.logEvent('house_created'), completes);
  });

  group('preferenza statistiche (toggle in Profilo)', () {
    // Le statistiche d'uso non sono un trattamento strettamente necessario:
    // devono restare disattivabili MANTENENDO l'account. È anche ciò che rende
    // veritiera la dichiarazione "raccolta opzionale" nel Data safety di Play.
    //
    // La preferenza è distinta dal consenso: `hasConsent` è un registro legale
    // (GDPR art. 7) e resta condizione per usare l'app; `analyticsEnabled` è
    // una scelta reversibile dell'utente.

    test('di default è attiva, per non disattivare a sorpresa', () async {
      final consent = ConsentService();
      await consent.load();
      expect(consent.analyticsEnabled, isTrue);
    });

    test('disattivarla chiude il gate pur restando il consenso', () async {
      final consent = ConsentService();
      await consent.load();
      await consent.record(policyVersion: '2026-07-30');
      final service = AppAnalyticsService(null, consent: consent);
      expect(service.mayTransmit, isTrue);

      await consent.setAnalyticsEnabled(false);

      expect(service.mayTransmit, isFalse);
      expect(
        consent.hasConsent,
        isTrue,
        reason:
            'disattivare le statistiche non deve cancellare il registro del '
            'consenso: sono due cose distinte',
      );
    });

    test('riattivarla riapre il gate', () async {
      final consent = ConsentService();
      await consent.load();
      await consent.record(policyVersion: '2026-07-30');
      final service = AppAnalyticsService(null, consent: consent);

      await consent.setAnalyticsEnabled(false);
      await consent.setAnalyticsEnabled(true);

      expect(service.mayTransmit, isTrue);
    });

    test(
      'senza consenso resta chiuso anche con la preferenza attiva',
      () async {
        final consent = ConsentService();
        await consent.load();
        await consent.setAnalyticsEnabled(true);

        expect(
          AppAnalyticsService(null, consent: consent).mayTransmit,
          isFalse,
          reason:
              'il consenso è il prerequisito, la preferenza non lo sostituisce',
        );
      },
    );

    test('la scelta sopravvive al riavvio dell\'app', () async {
      final first = ConsentService();
      await first.load();
      await first.record(policyVersion: '2026-07-30');
      await first.setAnalyticsEnabled(false);

      // Nuova istanza = nuova esecuzione dell'app, stesse SharedPreferences.
      final second = ConsentService();
      await second.load();

      expect(second.analyticsEnabled, isFalse);
      expect(AppAnalyticsService(null, consent: second).mayTransmit, isFalse);
    });
  });
}
