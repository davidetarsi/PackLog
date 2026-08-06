import 'package:amplitude_flutter/amplitude.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tgram_analytics/tgram_analytics.dart';

import '../../shared/config/app_config.dart';
import '../consent/consent_provider.dart';
import '../consent/consent_service.dart';
import 'analytics_session.dart';

part 'analytics_service.g.dart';

/// Sink degli eventi analytics: inoltra ad Amplitude e a tgram-analytics.
///
/// Questo è l'unico livello che conosce i backend concreti.
/// [CoreAnalyticsService] resta il livello tipato sopra di esso e non sa
/// quanti sink esistano: aggiungere tgram qui fa sì che **tutti** i metodi
/// tipati già esistenti si sdoppino senza modificarne nemmeno uno.
///
/// **Gate del consenso (GDPR).** Nessun evento parte, verso nessun backend,
/// finché l'utente non ha accettato privacy policy e termini. Il controllo
/// vive qui e non in [CoreAnalyticsService] perché diversi punti della UI
/// (login, onboarding, tour) chiamano `logEvent` direttamente, scavalcando il
/// livello tipato: questo è l'unico collo di bottiglia che li intercetta
/// tutti. Prima del gate venivano trasmessi gli eventi delle tre schermate di
/// onboarding e della schermata di login, cioè prima di qualunque consenso.
class AppAnalyticsService {
  final Amplitude? _amplitude;

  /// Session id per tgram-analytics. `null` disattiva il sink tgram
  /// (usato dai test, che costruiscono `AppAnalyticsService(null)`).
  final String? _tgramSessionId;

  /// Registro del consenso. `null` disattiva il gate: usato solo dai test che
  /// verificano l'inoltro ai sink senza passare dal consenso.
  final ConsentService? _consent;

  AppAnalyticsService(
    this._amplitude, {
    String? tgramSessionId,
    ConsentService? consent,
  }) : _tgramSessionId = tgramSessionId,
       _consent = consent;

  /// `true` se è lecito trasmettere. Fail-closed: un [ConsentService] che non
  /// ha ancora completato `load()` risponde `false`.
  ///
  /// Due condizioni, non una:
  ///
  /// - `hasConsent` — l'utente ha accettato privacy policy e termini. È il
  ///   prerequisito legale, e senza non si trasmette nulla.
  /// - `analyticsEnabled` — la preferenza modificabile da Profilo. Le
  ///   statistiche d'uso non sono strettamente necessarie, quindi devono
  ///   restare disattivabili **mantenendo l'account**.
  @visibleForTesting
  bool get mayTransmit =>
      _consent == null || (_consent.hasConsent && _consent.analyticsEnabled);

  /// Esegue [action] sul sink tgram, se attivo, assorbendo ogni errore.
  ///
  /// Due guardie, entrambe necessarie:
  ///
  /// 1. `_tgramSessionId == null` → sink disattivo (test).
  /// 2. `!TGA.isInitialized` → **bypassiamo deliberatamente il pre-init
  ///    buffering dell'SDK**. tgram bufferizza in memoria gli eventi emessi
  ///    prima di `init()` per poi flusharli, ma in flavor dev `init()` non
  ///    viene mai chiamato (vedi `_initNonCriticalServices` in
  ///    `bootstrap.dart`): senza questa guardia ogni evento resterebbe in un
  ///    buffer che cresce senza limite per tutta la durata della sessione.
  ///
  /// Il `catch` copre l'`ArgumentError` che `TGA.track` lancia su properties
  /// con Map/List annidate o valori non finiti. Oggi nessun evento di
  /// [CoreAnalyticsService] usa quelle forme, ma la garanzia "le analytics non
  /// rompono l'app" non deve dipendere da quel fatto restando vero in futuro.
  void _tgram(void Function(String sessionId) action) {
    final sessionId = _tgramSessionId;
    if (sessionId == null) return;
    if (!TGA.isInitialized) return;
    try {
      action(sessionId);
    } catch (e) {
      debugPrint('[Analytics] tgram sink failed: $e');
    }
  }

  /// Collega la sessione anonima corrente all'utente autenticato.
  ///
  /// Su tgram le properties passate a `identify` vengono ereditate da **tutti
  /// gli eventi successivi** della stessa sessione. Gli eventi già emessi
  /// prima del login restano anonimi, ma condividono il medesimo session id:
  /// lato server la sessione resta quindi ricollegabile all'utente.
  void identifyUser(String userId) {
    if (!mayTransmit) return;
    final amp = _amplitude;
    if (amp != null) {
      try {
        amp.setUserId(userId);
      } catch (e) {
        debugPrint('[Analytics] identifyUser failed: $e');
      }
    }
    _tgram((sessionId) => TGA.identify(sessionId, {'user_id': userId}));
  }

  /// Deliberatamente **non** protetto dal gate: dissociare l'identità è
  /// un'operazione che riduce i dati, non che li trasmette. Bloccarla potrebbe
  /// lasciare attaccata un'identità stale, cioè il contrario di ciò che il
  /// gate vuole ottenere.
  void clearUser() {
    final amp = _amplitude;
    if (amp != null) {
      try {
        amp.setUserId(null);
      } catch (e) {
        debugPrint('[Analytics] clearUser failed: $e');
      }
    }
    // Scarta le properties della sessione: dopo il logout gli eventi della
    // stessa esecuzione non devono più essere attribuiti all'utente uscito.
    _tgram((sessionId) => TGA.forget(sessionId));
  }

  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    // Gli eventi emessi prima del consenso vengono scartati, non accodati:
    // conservarli per spedirli dopo significherebbe comunque averli
    // raccolti senza base giuridica.
    if (!mayTransmit) return;
    final amp = _amplitude;
    if (amp != null) {
      try {
        await amp.logEvent(eventName, eventProperties: properties);
      } catch (e) {
        debugPrint('[Analytics] logEvent "$eventName" failed: $e');
      }
    }
    _tgram(
      (sessionId) => TGA.track(eventName, sessionId, properties: properties),
    );
  }
}

@Riverpod(keepAlive: true)
AppAnalyticsService analyticsService(Ref ref) {
  final amplitude = AppConfig.amplitudeApiKey == 'MISSING_AMPLITUDE_API_KEY'
      ? null
      : Amplitude.getInstance();
  return AppAnalyticsService(
    amplitude,
    tgramSessionId: ref.watch(analyticsSessionIdProvider),
    consent: ref.watch(consentServiceProvider),
  );
}
