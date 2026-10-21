import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/promo_redeem_result.dart';

/// Codici promo: attivazione sul server e codice "in attesa" sul telefono.
///
/// Il codice si può scrivere sulla schermata di login, quando l'utente non
/// esiste ancora su Supabase: lì viene solo salvato in locale
/// ([savePending]) e attivato subito dopo il primo accesso
/// ([redeemPending], chiamato da `AuthNotifier`). Dal profilo invece si
/// attiva subito ([redeem]).
class PromoCodeService {
  PromoCodeService({SupabaseClient? client, Future<SharedPreferences>? prefs})
    : _client = client,
      _prefs = prefs;

  static const String _pendingKey = 'promo_code_pending';

  final SupabaseClient? _client;
  final Future<SharedPreferences>? _prefs;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  Future<SharedPreferences> get _preferences =>
      _prefs ?? SharedPreferences.getInstance();

  /// Il codice come lo vuole il server: senza spazi, maiuscolo.
  static String normalize(String code) => code.trim().toUpperCase();

  Future<void> savePending(String code) async {
    final prefs = await _preferences;
    await prefs.setString(_pendingKey, normalize(code));
  }

  Future<String?> pendingCode() async {
    final prefs = await _preferences;
    return prefs.getString(_pendingKey);
  }

  Future<void> clearPending() async {
    final prefs = await _preferences;
    await prefs.remove(_pendingKey);
  }

  /// Attiva [code] per l'utente loggato.
  Future<PromoRedeemResult> redeem(String code) async {
    try {
      final data = await _supabase.rpc(
        'redeem_promo_code',
        params: {'p_code': normalize(code)},
      );
      return parseResponse(data);
    } catch (e) {
      debugPrint('[Promo] attivazione fallita: $e');
      return const PromoFailed();
    }
  }

  /// Attiva il codice salvato al login, se c'è. Restituisce null se non c'era
  /// nessun codice. Il codice in attesa resta salvato solo se la richiesta
  /// non è arrivata, per riprovare al login successivo.
  Future<PromoRedeemResult?> redeemPending() async {
    final code = await pendingCode();
    if (code == null || code.isEmpty) return null;
    final result = await redeem(code);
    if (result is! PromoFailed) await clearPending();
    return result;
  }

  @visibleForTesting
  static PromoRedeemResult parseResponse(Object? data) {
    if (data is! Map) return const PromoFailed();
    if (data['ok'] == true) {
      final expiresAt = DateTime.tryParse('${data['expires_at']}');
      final credits = data['credits'];
      if (credits is! int || expiresAt == null) return const PromoFailed();
      return PromoRedeemed(credits: credits, expiresAt: expiresAt.toLocal());
    }
    return PromoRejected(PromoRejectReason.fromCode(data['error'] as String?));
  }
}
