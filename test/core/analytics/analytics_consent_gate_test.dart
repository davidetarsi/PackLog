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
}
