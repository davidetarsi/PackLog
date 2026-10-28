import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../model/clothing_analysis_exception.dart';
import '../model/clothing_analysis_result.dart';

// ── Service ───────────────────────────────────────────────────────────────────

/// Orchestrates the AI clothing analysis pipeline:
/// 1. [TEMPORANEAMENTE DISABILITATO] Background removal via Remove.bg API.
/// 2. Scheda dei capi dalla foto con l'edge function `item-metadata`
///    (Claude riempie la scheda, il server la pulisce e la controlla).
///
/// Inject an [http.Client] for testability; defaults to `http.Client()`.
///
/// **Nota sicurezza**: modello, prompt e limiti sono fissati SERVER-SIDE.
/// Questo servizio invia solo `image_base64` e `lang`, la lingua del nome dei
/// capi (vedi `supabase/functions/item-metadata/index.ts`, che rifiuta un
/// body con anche `name`). Non aggiungere altri campi al body.
class AiClothingAnalyzerService {
  // static const _removeBgEndpoint = 'https://api.remove.bg/v1.0/removebg'; // ← REMOVE.BG DISABILITATO

  // final String _removeBgApiKey; // ← REMOVE.BG DISABILITATO
  final String _proxyUrl;
  final String _anonKey;
  final http.Client _client;
  final String? Function() _jwtProvider;

  /// La lingua dell'app ('it' o 'en'): il nome dei capi si scrive in questa.
  final String Function() _language;
  final CoreAnalyticsService? _analytics;
  final AppMonitoringService? _monitoring;

  AiClothingAnalyzerService({
    // required String removeBgApiKey, // ← REMOVE.BG DISABILITATO
    required String proxyUrl,
    required String anonKey,
    http.Client? client,
    String? Function()? jwtProvider,
    String Function()? language,
    CoreAnalyticsService? analytics,
    AppMonitoringService? monitoring,
  }) : // _removeBgApiKey = removeBgApiKey, // ← REMOVE.BG DISABILITATO
       _proxyUrl = proxyUrl,
       _anonKey = anonKey,
       _client = client ?? http.Client(),
       _jwtProvider =
           jwtProvider ??
           (() => Supabase.instance.client.auth.currentSession?.accessToken),
       _language = language ?? (() => 'it'),
       _analytics = analytics,
       _monitoring = monitoring;

  // ── Public orchestrators ──────────────────────────────────────────────────

  /// Analizza il file immagine con `item-metadata` (senza step di rimozione
  /// background).
  ///
  /// Throws a [ClothingAnalysisException] subclass on any failure.
  Future<List<ClothingItem>> processClothingItem(File imageFile) async {
    _analytics?.trackAiInputSubmitted();
    try {
      // REMOVE.BG DISABILITATO: si salta lo step di background removal
      // final Uint8List transparentPng = await _removeBackground(imageFile);
      // return (await _analyzeImage(transparentPng)).items;

      final Uint8List imageBytes = await imageFile.readAsBytes();
      final result = await _analyzeImage(imageBytes);
      _analytics?.trackAiInputCompleted(itemCount: result.length);
      return result;
    } on ClothingAnalysisException catch (e, st) {
      _analytics?.trackAiInputFailed(errorType: _errorType(e));
      _monitoring?.captureException(
        e,
        stackTrace: st,
        tags: {'operation': 'ai_input'},
      );
      rethrow;
    }
  }

  static String _errorType(ClothingAnalysisException e) => switch (e) {
    VisionAnalysisException() => 'VisionAnalysisException',
    ResponseParsingException() => 'ResponseParsingException',
    GptLimitExceededException() => 'GptLimitExceededException',
    BackgroundRemovalException() => 'BackgroundRemovalException',
    AnalysisNetworkException() => 'AnalysisNetworkException',
    AnalysisNotAuthenticatedException() => 'AnalysisNotAuthenticatedException',
  };

  // ── Step 1: Background removal [DISABILITATO] ─────────────────────────────
  //
  // Riabilitare quando si vuole usare la pipeline completa con Remove.bg.
  //
  // /// Sends the image to the Remove.bg API and returns the PNG bytes.
  // /// Throws [BackgroundRemovalException] on non-2xx response or network error.
  // Future<Uint8List> _removeBackground(File imageFile) async {
  //   final uri = Uri.parse(_removeBgEndpoint);
  //   final request = http.MultipartRequest('POST', uri)
  //     ..headers['X-Api-Key'] = _removeBgApiKey
  //     ..fields['size'] = 'auto'
  //     ..files.add(
  //       await http.MultipartFile.fromPath('image_file', imageFile.path),
  //     );
  //   try {
  //     final streamedResponse = await _client.send(request);
  //     final response = await http.Response.fromStream(streamedResponse);
  //     if (response.statusCode < 200 || response.statusCode >= 300) {
  //       throw BackgroundRemovalException(
  //         'Remove.bg returned ${response.statusCode}: ${response.body}',
  //       );
  //     }
  //     return response.bodyBytes;
  //   } on BackgroundRemovalException {
  //     rethrow;
  //   } on Exception catch (e) {
  //     throw BackgroundRemovalException('Network error during background removal: $e');
  //   }
  // }

  // ── Step 2: Vision analysis ───────────────────────────────────────────────

  /// Sends the image bytes to `item-metadata` and parses the result.
  ///
  /// Throws [VisionAnalysisException] on non-2xx response.
  /// Throws [ResponseParsingException] on schema mismatch or malformed JSON.
  Future<List<ClothingItem>> _analyzeImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    // Body minimale: la funzione decide modello, prompt e limiti server-side
    // per impedire al client di alterare costi o uso del modello.
    final body = jsonEncode({'image_base64': base64Image, 'lang': _language()});

    final jwt = _jwtProvider();
    if (jwt == null || jwt.isEmpty) {
      throw const AnalysisNotAuthenticatedException('User not authenticated');
    }

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_proxyUrl),
        headers: {
          'Authorization': 'Bearer $jwt',
          'apikey': _anonKey,
          'Content-Type': 'application/json',
        },
        // utf8.encode (List<int>) preserva Content-Type: application/json.
        // Passare body come String farebbe sovrascrivere il Content-Type a
        // text/plain dal setter Request.body del pacchetto http.
        body: utf8.encode(body),
      );
    } on Exception catch (e) {
      // Il messaggio resta tecnico di proposito: serve a Sentry e ai log, non
      // alla UI. Chi lo mostra deve passare da AiFailureReason.
      throw AnalysisNetworkException(
        'Network error during vision analysis: $e',
      );
    }

    if (response.statusCode == 429) {
      throw const GptLimitExceededException(
        'GPT usage limit reached (HTTP 429)',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VisionAnalysisException(
        'item-metadata returned ${response.statusCode}: ${response.body}',
      );
    }

    return _parseItemMetadataResponse(response.body);
  }

  // ── Response parsing ──────────────────────────────────────────────────────

  /// Legge `{ items: [{ metadata, app_category, dubbi }], note_tecniche }`.
  /// Nessun capo riconosciuto (anche una risposta del modello che non era
  /// JSON) arriva come `items: []`.
  ///
  /// Throws [ResponseParsingException] if the body doesn't have that shape.
  List<ClothingItem> _parseItemMetadataResponse(String responseBody) {
    try {
      final body = jsonDecode(responseBody) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      return items
          .map(
            (item) =>
                ClothingItem.fromItemMetadata(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ResponseParsingException(
        'Could not parse item-metadata response: $e\nRaw body: $responseBody',
      );
    }
  }
}
