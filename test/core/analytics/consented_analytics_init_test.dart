import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inizializzazione differita degli SDK di analytics.
///
/// Il gate in `AppAnalyticsService` (vedi `analytics_consent_gate_test.dart`)
/// impedisce di *trasmettere* eventi senza consenso, ma non basta:
/// `Amplitude.init()` apre per conto proprio una sessione e raccoglie
/// proprietà del dispositivo, quindi è esso stesso un trattamento e va
/// posticipato al consenso. Senza questa separazione la dichiarazione
/// "analytics opzionali" nel Data safety di Play sarebbe falsa — e Google
/// rileva Amplitude scansionando l'AAB.
///
/// In ambiente di test le chiavi non sono definite (`MISSING_*`), quindi
/// `initConsentedAnalytics()` non tocca alcun SDK reale: qui si verifica
/// soltanto la guardia di idempotenza, che è la logica introdotta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetConsentedAnalyticsForTest();
  });

  test('non è partita finché nessuno la invoca', () {
    expect(
      consentedAnalyticsStarted,
      isFalse,
      reason:
          'senza consenso il bootstrap non deve inizializzare gli SDK: '
          'chi apre l\'app la prima volta non ha ancora acconsentito',
    );
  });

  test('la prima invocazione la marca come partita', () async {
    await initConsentedAnalytics();
    expect(consentedAnalyticsStarted, isTrue);
  });

  test('è idempotente: invocazioni successive sono no-op', () async {
    await initConsentedAnalytics();
    // Ri-spuntare la casella del consenso, o riaprire la schermata di login,
    // non deve reinizializzare gli SDK.
    await initConsentedAnalytics();
    await initConsentedAnalytics();

    expect(consentedAnalyticsStarted, isTrue);
  });
}
