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

  DateTime? _givenAt;
  String? _policyVersion;
  bool _syncedRemote = false;
  bool _loaded = false;

  /// `true` se l'utente ha prestato il consenso e lo stato è già stato letto
  /// da disco. È la guardia usata dal gate analytics.
  bool get hasConsent => _loaded && _givenAt != null;

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
    } catch (e) {
      // Fail-closed: senza stato leggibile restiamo senza consenso.
      debugPrint('[Consent] load fallita: $e');
      _givenAt = null;
      _policyVersion = null;
      _syncedRemote = false;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_givenAtKey);
    await prefs.remove(_policyVersionKey);
    await prefs.remove(_syncedRemoteKey);
  }
}
