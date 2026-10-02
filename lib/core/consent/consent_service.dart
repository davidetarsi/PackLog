import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registro locale del consenso a privacy policy e termini di servizio.
///
/// Il consenso viene prestato sulla schermata di login — quindi **prima** che
/// esista una sessione autenticata e prima che la riga dell'utente esista su
/// Supabase. Questo servizio lo registra localmente e mantiene il flag di
/// avvenuto invio al server, così [ConsentFlusher] può riversarlo alla prima
/// occasione utile conservando il timestamp originale.
///
/// **Lettura sincrona**: [hasConsent] deve poter essere interrogato dentro
/// `AppAnalyticsService.logEvent`, che è nel percorso caldo di ogni evento e
/// non può attendere una `Future`. Lo stato viene quindi tenuto in memoria e
/// idratato una sola volta all'avvio da [load].
///
/// **Fail-closed**: finché [load] non ha completato, [hasConsent] è `false`.
/// Nella finestra di pochi millisecondi tra l'avvio e l'idratazione qualche
/// evento può andare perso — è la direzione giusta in cui sbagliare, perché
/// l'alternativa sarebbe trasmettere senza avere ancora verificato il
/// consenso.
class ConsentService {
  static const String _givenAtKey = 'consent_given_at';
  static const String _policyVersionKey = 'consent_policy_version';
  static const String _syncedRemoteKey = 'consent_synced_remote';
  static const String _analyticsEnabledKey = 'analytics_enabled';

  DateTime? _givenAt;
  String? _policyVersion;
  bool _syncedRemote = false;
  bool _loaded = false;
  bool _analyticsEnabled = true;

  /// `true` se l'utente ha prestato il consenso e lo stato è già stato letto
  /// da disco. È la guardia usata dal gate analytics.
  bool get hasConsent => _loaded && _givenAt != null;

  /// Preferenza sulle statistiche d'uso, modificabile da Profilo.
  ///
  /// **Distinta dal consenso**, e volutamente non fusa con [hasConsent]:
  ///
  /// - [hasConsent] è un **registro legale** (GDPR art. 7): documenta che a un
  ///   certo istante l'utente ha accettato privacy policy e termini. Non si
  ///   "disfa": al più si registra una revoca. Ed è condizione per usare
  ///   l'app, quindi non può essere spento a piacere.
  /// - [analyticsEnabled] è una **preferenza**: le statistiche d'uso non sono
  ///   un trattamento strettamente necessario, quindi devono restare
  ///   disattivabili **mantenendo l'account**. È ciò che rende veritiera la
  ///   dichiarazione "raccolta opzionale" nel Data safety di Play.
  ///
  /// Default `true`: chi ha appena accettato i documenti non viene disattivato
  /// a sorpresa. Il gate a monte resta comunque [hasConsent], quindi prima del
  /// consenso questo valore è irrilevante.
  bool get analyticsEnabled => _analyticsEnabled;

  /// Istante in cui la casella è stata spuntata (t0). Da usare per il flush
  /// remoto: il registro deve riportare quando il consenso è stato prestato,
  /// non quando è stato trasmesso.
  DateTime? get givenAt => _givenAt;

  String? get policyVersion => _policyVersion;

  /// `true` se c'è un consenso locale non ancora riversato su Supabase.
  bool get needsRemoteFlush => _givenAt != null && !_syncedRemote;

  /// Idrata lo stato da [SharedPreferences]. Idempotente.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_givenAtKey);
      _givenAt = raw == null ? null : DateTime.tryParse(raw);
      _policyVersion = prefs.getString(_policyVersionKey);
      _syncedRemote = prefs.getBool(_syncedRemoteKey) ?? false;
      _analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? true;
    } catch (e) {
      // Fail-closed: senza stato leggibile restiamo senza consenso.
      debugPrint('[Consent] load fallita: $e');
      _givenAt = null;
      _policyVersion = null;
      _syncedRemote = false;
      // `_analyticsEnabled` resta al default: è comunque irrilevante finché
      // `hasConsent` è false, e il gate a monte blocca tutto.
    } finally {
      _loaded = true;
    }
  }

  /// Registra il consenso adesso, per [policyVersion].
  ///
  /// Lo stato in memoria viene aggiornato **prima** della scrittura su disco:
  /// il chiamante emette l'evento `consent_given` subito dopo, e il gate deve
  /// già vederlo attivo anche se la persistenza è più lenta.
  ///
  /// "First write wins": se un consenso esiste già non viene sovrascritto,
  /// per non spostare in avanti la data di un consenso più vecchio.
  Future<void> record({required String policyVersion}) async {
    if (_givenAt != null) return;

    final now = DateTime.now().toUtc();
    _givenAt = now;
    _policyVersion = policyVersion;
    _syncedRemote = false;
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_givenAtKey, now.toIso8601String());
      await prefs.setString(_policyVersionKey, policyVersion);
      await prefs.setBool(_syncedRemoteKey, false);
    } catch (e) {
      // Lo stato in memoria resta valido per questa esecuzione: il consenso
      // è stato prestato davvero. Al prossimo avvio verrà richiesto di nuovo.
      debugPrint('[Consent] persistenza fallita: $e');
    }
  }

  /// Revoca il consenso registrato solo in locale.
  ///
  /// Copre il caso concreto in cui l'utente spunta la casella, apre la privacy
  /// policy, e la despunta: senza questo resterebbe agli atti un consenso che
  /// è stato ritirato prima ancora di procedere.
  ///
  /// Ammessa **solo prima del flush remoto**. Dopo il login la revoca non è
  /// più una faccenda locale: il registro sta su Supabase e va aggiornato lì.
  Future<void> revokeLocal() async {
    if (_syncedRemote) return;

    _givenAt = null;
    _policyVersion = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_givenAtKey);
      await prefs.remove(_policyVersionKey);
      await prefs.remove(_syncedRemoteKey);
    } catch (e) {
      debugPrint('[Consent] revokeLocal fallita: $e');
    }
  }

  /// Attiva o disattiva le statistiche d'uso.
  ///
  /// Lo stato in memoria viene aggiornato **prima** della scrittura su disco,
  /// come in [record]: il gate è sincrono e deve vedere subito il nuovo valore,
  /// altrimenti un evento emesso nell'istante successivo passerebbe ancora.
  ///
  /// Disattivandole, spetta al chiamante dissociare anche l'identità già
  /// inviata ai backend (`AppAnalyticsService.clearUser`): questo servizio
  /// registra la preferenza, non parla con gli SDK.
  Future<void> setAnalyticsEnabled(bool value) async {
    if (_analyticsEnabled == value) return;
    _analyticsEnabled = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsEnabledKey, value);
    } catch (e) {
      // Lo stato in memoria resta valido per questa esecuzione: se l'utente ha
      // disattivato, da adesso non si trasmette comunque più nulla.
      debugPrint('[Consent] setAnalyticsEnabled fallita: $e');
    }
  }

  /// Marca il consenso come riversato su Supabase, così i login successivi
  /// non ripetono la chiamata.
  Future<void> markSyncedRemote() async {
    _syncedRemote = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncedRemoteKey, true);
    } catch (e) {
      // Non critico: la RPC è idempotente, al più si riproverà.
      debugPrint('[Consent] markSyncedRemote fallita: $e');
    }
  }

  /// Azzera il registro locale. Solo per i test.
  @visibleForTesting
  Future<void> reset() async {
    _givenAt = null;
    _policyVersion = null;
    _syncedRemote = false;
    _loaded = false;
    _analyticsEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_givenAtKey);
    await prefs.remove(_policyVersionKey);
    await prefs.remove(_syncedRemoteKey);
    await prefs.remove(_analyticsEnabledKey);
  }
}
