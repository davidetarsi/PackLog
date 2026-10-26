import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_config.dart';
import '../model/ai_packing.dart';

part 'pack_trip_service.g.dart';

/// La funzione ha risposto 429: il tetto di crediti AI dell'utente è finito.
class PackTripCreditsException implements Exception {
  const PackTripCreditsException();
}

/// 422 "Wardrobe is empty": nell'armadio della casa non c'è nessun capo.
class PackTripEmptyWardrobeException implements Exception {
  const PackTripEmptyWardrobeException();
}

/// 422 "Wardrobe too large": l'armadio supera il massimo di capi.
class PackTripWardrobeTooLargeException implements Exception {
  const PackTripWardrobeTooLargeException();
}

/// Valigia non arrivata: rete, sessione, errore della funzione o risposta
/// illeggibile.
class PackTripException implements Exception {
  const PackTripException(this.message);

  final String message;

  @override
  String toString() => 'PackTripException: $message';
}

/// La valigia AI dalla funzione `pack-trip`.
class PackTripService {
  PackTripService({http.Client Function()? client, String? Function()? token})
    : _newClient = client ?? http.Client.new,
      _token = token ?? _sessionToken;

  final http.Client Function() _newClient;
  final String? Function() _token;

  _PackTripAttempt? _attempt;

  static String? _sessionToken() =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  /// Genera la valigia di [body] per la casa [houseId]. Solleva le eccezioni
  /// `PackTrip*`: quelle di credito e armadio hanno un tipo proprio, il resto
  /// è [PackTripException]. Annullata con [cancel], solleva
  /// `PackTripException('annullata')`.
  Future<AiPackingResult> generate(
    Map<String, dynamic> body, {
    required String houseId,
  }) async {
    // La funzione conta le chiamate per utente: serve il JWT della sessione.
    final jwt = _token();
    if (jwt == null) throw const PackTripException('nessuna sessione');

    final client = _newClient();
    final attempt = _PackTripAttempt(client);
    _attempt = attempt;

    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('${AppConfig.supabaseUrl}/functions/v1/pack-trip'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      if (attempt.cancelled) throw const PackTripException('annullata');
      throw PackTripException('rete: $e');
    } finally {
      if (identical(_attempt, attempt)) _attempt = null;
      client.close();
    }
    if (attempt.cancelled) throw const PackTripException('annullata');

    if (response.statusCode == 429) throw const PackTripCreditsException();
    if (response.statusCode == 422) {
      final messaggio = _messaggioErrore(response.body);
      if (messaggio.contains('Wardrobe is empty')) {
        throw const PackTripEmptyWardrobeException();
      }
      if (messaggio.contains('Wardrobe too large')) {
        throw const PackTripWardrobeTooLargeException();
      }
    }
    if (response.statusCode != 200) {
      debugPrint(
        '[PackTripService] HTTP ${response.statusCode}: ${response.body}',
      );
      throw PackTripException('HTTP ${response.statusCode}');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw PackTripException('risposta non valida: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PackTripException('risposta non valida: non è un oggetto');
    }
    return parsePackTripResponse(
      decoded,
      houseId: houseId,
      now: DateTime.now(),
    );
  }

  /// Annulla la generazione in corso, se c'è.
  void cancel() {
    final attempt = _attempt;
    _attempt = null;
    attempt?.cancel();
  }

  /// Il campo `error` del corpo d'errore, o stringa vuota.
  static String _messaggioErrore(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Corpo non JSON: nessun messaggio riconoscibile.
    }
    return '';
  }
}

/// Una generazione in corso: il suo client, e se è stata annullata.
class _PackTripAttempt {
  _PackTripAttempt(this.client);

  final http.Client client;
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    client.close();
  }
}

/// Traduce la risposta di `pack-trip` (chiavi italiane, snake_case) nel
/// modello [AiPackingResult], campo per campo. Un avviso con livello
/// sconosciuto si scarta; un array opzionale mancante vale come lista vuota;
/// una struttura illeggibile solleva [PackTripException].
AiPackingResult parsePackTripResponse(
  Map<String, dynamic> json, {
  required String houseId,
  required DateTime now,
}) {
  try {
    final proposal = [
      for (final raw in _lista(json['capi']))
        _capo(raw as Map<String, dynamic>),
    ];
    final warnings = [
      for (final raw in _lista(json['avvisi']))
        if (_livello((raw as Map<String, dynamic>)['livello']) != null)
          _avviso(raw),
    ];
    final reasons = [
      for (final raw in _lista(json['perche']))
        _punto(raw as Map<String, dynamic>),
    ];
    return AiPackingResult(
      generatedAt: now,
      houseId: houseId,
      proposal: proposal,
      warnings: warnings,
      reasons: reasons,
    );
  } on PackTripException {
    rethrow;
  } catch (e) {
    throw PackTripException('risposta non valida: $e');
  }
}

/// Un array opzionale: assente o null vale come vuoto.
List<dynamic> _lista(Object? raw) => raw == null ? const [] : raw as List;

List<String> _stringhe(Object? raw) =>
    _lista(raw).map((value) => value as String).toList();

AiPackedItem _capo(Map<String, dynamic> json) {
  final motivo = json['motivo'] as Map<String, dynamic>;
  return AiPackedItem(
    itemId: json['item_id'] as String,
    quantity: (json['quantita'] as num).toInt(),
    inDeparture: json['in_partenza'] as bool? ?? false,
    reason: AiReason(
      code: motivo['codice'] as String,
      label: motivo['etichetta'] as String,
      sentence: motivo['frase'] as String,
    ),
  );
}

AiWarningLevel? _livello(Object? raw) => switch (raw) {
  'importante' => AiWarningLevel.important,
  'utile' => AiWarningLevel.useful,
  _ => null,
};

AiWarning _avviso(Map<String, dynamic> json) => AiWarning(
  id: json['id'] as String,
  code: json['codice'] as String,
  level: _livello(json['livello'])!,
  title: json['titolo'] as String,
  why: json['perche'] as String,
  search: json['cerca'] as String?,
);

AiReasonPoint _punto(Map<String, dynamic> json) => AiReasonPoint(
  code: json['codice'] as String,
  title: json['titolo'] as String,
  sentences: _stringhe(json['frasi']),
  items: _stringhe(json['capi']),
);

@riverpod
PackTripService packTripService(Ref ref) => PackTripService();
