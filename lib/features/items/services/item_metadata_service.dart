import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../../core/once_per_day.dart';
import '../model/item_model.dart';

/// La scheda di un oggetto aggiunto a mano, dall'edge function
/// `item-metadata` (`{ name }`): la stessa che riempie lo scan da foto.
class ItemMetadataResult {
  const ItemMetadataResult({required this.metadata, this.category});

  /// Da salvare in `items.ai_metadata`.
  final Map<String, dynamic> metadata;

  /// La categoria dell'app decisa dal server; null se non è una nota.
  final ItemCategory? category;
}

/// Risposta non 200 (e non 429) di `item-metadata`, per Sentry: lo stato e
/// il messaggio d'errore della funzione (`{error: "..."}`, testi fissi
/// scritti da noi). Il resto del corpo non entra: non è nostro e potrebbe
/// contenere testo dell'utente, che la privacy policy non prevede in Sentry.
class ItemMetadataHttpException implements Exception {
  const ItemMetadataHttpException(this.statusCode, [this.serverError]);

  /// Il messaggio `error` della risposta da [body], al massimo 200
  /// caratteri; null se il corpo non è un JSON con quel campo.
  factory ItemMetadataHttpException.from(int statusCode, String body) {
    String? message;
    try {
      final json = jsonDecode(body);
      final error = json is Map ? json['error'] : null;
      if (error is String && error.trim().isNotEmpty) {
        final text = error.trim();
        message = text.length > 200 ? text.substring(0, 200) : text;
      }
    } on FormatException {
      message = null;
    }
    return ItemMetadataHttpException(statusCode, message);
  }

  final int statusCode;
  final String? serverError;

  @override
  String toString() =>
      'ItemMetadataHttpException: HTTP $statusCode'
      '${serverError == null ? '' : ' — $serverError'}';
}

/// Risposta 200 che non si legge come JSON, per Sentry. Prende il posto della
/// `FormatException`, il cui messaggio riporta un pezzo del corpo.
class ItemMetadataParseException implements Exception {
  const ItemMetadataParseException();

  @override
  String toString() => 'ItemMetadataParseException: risposta non JSON';
}

/// Chiede la scheda di un oggetto dal solo nome.
///
/// Non lancia mai: senza rete, senza sessione, a limite raggiunto o con una
/// risposta strana restituisce null e l'oggetto resta com'è. Il nome non
/// consuma crediti AI (ha un limite giornaliero lato server).
///
/// Il limite raggiunto è un evento ([CoreAnalyticsService.trackAiLimitReached]);
/// gli altri errori del server e le risposte illeggibili vanno in Sentry, la
/// rete assente no.
class ItemMetadataService {
  ItemMetadataService({
    required String url,
    required String anonKey,
    http.Client? client,
    String? Function()? jwtProvider,
    String Function()? language,
    CoreAnalyticsService? analytics,
    AppMonitoringService? monitoring,
  }) : _url = url,
       _analytics = analytics,
       _monitoring = monitoring,
       _language = language ?? (() => 'it'),
       _anonKey = anonKey,
       _client = client ?? http.Client(),
       _jwtProvider =
           jwtProvider ??
           (() => Supabase.instance.client.auth.currentSession?.accessToken);

  final String _url;
  final String _anonKey;
  final http.Client _client;
  final String? Function() _jwtProvider;
  final CoreAnalyticsService? _analytics;
  final AppMonitoringService? _monitoring;

  /// La lingua dell'app ('it' o 'en'), per i testi che scrive il server.
  final String Function() _language;

  /// Chi chiede la scheda, per `ai_limit_reached`: un'aggiunta dell'utente.
  static const sourceManual = 'manual';

  /// Il recupero in background delle schede mancanti.
  static const sourceBackfill = 'backfill';

  Future<ItemMetadataResult?> fromName(
    String name, {
    String source = sourceManual,
  }) async {
    try {
      final jwt = _jwtProvider();
      if (jwt == null || jwt.isEmpty || name.trim().isEmpty) return null;
      final response = await _client
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey': _anonKey,
              'Content-Type': 'application/json',
            },
            body: utf8.encode(
              jsonEncode({'name': name.trim(), 'lang': _language()}),
            ),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 429) {
        _analytics?.trackAiLimitReached(feature: 'item_name', source: source);
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint('[ItemMetadata] ${response.statusCode}: ${response.body}');
        _monitoring?.captureException(
          ItemMetadataHttpException.from(response.statusCode, response.body),
          tags: {
            'operation': 'item_metadata',
            'status': '${response.statusCode}',
          },
        );
        return null;
      }
      return parse(response.body);
    } catch (e, st) {
      debugPrint('[ItemMetadata] scheda non ottenuta: $e');
      if (!isNetworkFailure(e)) {
        // Il messaggio di una FormatException riporta un pezzo del corpo.
        _monitoring?.captureException(
          e is FormatException ? const ItemMetadataParseException() : e,
          stackTrace: st,
          tags: {'operation': 'item_metadata'},
        );
      }
      return null;
    }
  }

  /// `{ items: [{ metadata, app_category, dubbi }] }` -> il primo capo.
  @visibleForTesting
  static ItemMetadataResult? parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final items = json['items'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final metadata = first['metadata'];
    if (metadata is! Map<String, dynamic>) return null;
    final appCategory = first['app_category'];
    return ItemMetadataResult(
      metadata: metadata,
      category: ItemCategory.values
          .where((c) => c.name == appCategory)
          .firstOrNull,
    );
  }
}
