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
/// 2. Structured fashion analysis via OpenAI GPT-4o Vision API.
///
/// Inject an [http.Client] for testability; defaults to `http.Client()`.
class AiClothingAnalyzerService {
  // static const _removeBgEndpoint = 'https://api.remove.bg/v1.0/removebg'; // ← REMOVE.BG DISABILITATO

  /* static const _systemPrompt = '''
You are a precise fashion item parser. Analyze the image and identify ALL distinct clothing items currently WORN by the PRIMARY person in the foreground.
CRITICAL RULES:
- IGNORE any clothing items in the background (e.g., clothes on beds, chairs, hangers, or worn by other people passing by).
- Focus ONLY on the main subject's outfit.
Respond ONLY with a raw JSON array of objects — no markdown, no code fences.
Each object in the array must have exactly these keys:
- "name": string (A short, descriptive name, e.g. "Giacca in pelle", "Jeans strappati". Write this in Italian.)
- "category": string (e.g. "Upper Body", "Lower Body", "Shoes", "Outerwear", "Accessory")
- "color": string (e.g. "Nero", "Bianco", "Multicolore")
- "season": string (e.g. "Summer", "Winter", "Demiseason", "All Season")
- "styleTags": array of strings (e.g. ["Casual", "Streetwear", "Y2K"])
'''; */

  static const _systemPrompt = '''
You are a precise fashion item parser. Analyze the image and identify ALL distinct clothing items currently WORN by the PRIMARY person in the foreground.
CRITICAL RULES:
- IGNORE any clothing items in the background (e.g., clothes on beds, chairs, hangers).
- Focus ONLY on the main subject's outfit.
Respond ONLY with a raw JSON array of objects — no markdown, no code fences.
Each object must have EXACTLY these keys:
- "name": string (Short descriptive name in Italian, e.g. "Giacca in pelle", "Jeans slim")
- "category": string (ONE OF: "Upper Body", "Lower Body", "Shoes", "Outerwear", "Accessory")
- "subCategory": string (ONE OF based on category:
  Upper Body → "T-Shirt", "Shirt", "Polo", "Hoodie", "Sweatshirt", "Sweater", "Tank Top", "Crop Top"
  Lower Body → "Jeans", "Shorts", "Trousers", "Leggings", "Skirt", "Sweatpants", "Swimwear"
  Shoes → "Sneakers", "Sandals", "Boots", "Flip-Flops", "Loafers", "Dress Shoes", "Hiking Boots"
  Outerwear → "Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Blazer"
  Accessory → "Cap/Hat", "Belt", "Bag", "Scarf", "Sunglasses", "Jewelry", "Watch")
- "baseColor": string (Primary color in Italian, e.g. "Nero", "Bianco", "Blu navy")
- "pattern": string (ONE OF: "Solid", "Striped", "Plaid", "Graphic", "Logo", "Floral", "Other")
- "coverage": string (ONE OF: "Short-sleeve", "Long-sleeve", "Sleeveless", "Shorts", "Full-length", "Cropped", "N/A")
- "fit": string (ONE OF: "Skinny", "Regular", "Oversize", "N/A")
- "warmth": integer (1 to 5: 1=canottiera/sandali, 2=t-shirt/sneakers, 3=felpa/jeans, 4=cappotto/stivali, 5=piumino/scarponi)
- "formality": string (ONE OF: "Loungewear", "Casual", "Smart Casual", "Business", "Formal")
- "activityTags": array of 1-3 strings (ONLY from: ["Everyday", "Office", "Beach", "Swimming", "Hiking", "Sport", "Formal", "Lounge"])
''';

  // final String _removeBgApiKey; // ← REMOVE.BG DISABILITATO
  final String _proxyUrl;
  final String _anonKey;
  final http.Client _client;
  final String? Function() _jwtProvider;
  final CoreAnalyticsService? _analytics;
  final AppMonitoringService? _monitoring;

  AiClothingAnalyzerService({
    // required String removeBgApiKey, // ← REMOVE.BG DISABILITATO
    required String proxyUrl,
    required String anonKey,
    http.Client? client,
    String? Function()? jwtProvider,
    CoreAnalyticsService? analytics,
    AppMonitoringService? monitoring,
  }) : // _removeBgApiKey = removeBgApiKey, // ← REMOVE.BG DISABILITATO
       _proxyUrl = proxyUrl,
       _anonKey = anonKey,
       _client = client ?? http.Client(),
       _jwtProvider =
           jwtProvider ??
           (() => Supabase.instance.client.auth.currentSession?.accessToken),
       _analytics = analytics,
       _monitoring = monitoring;

  // ── Public orchestrators ──────────────────────────────────────────────────

  /// Analizza il file immagine passando direttamente a GPT-4o Vision
  /// (senza step di rimozione background).
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

  /// Sends the image bytes to GPT-4o Vision and parses the result.
  ///
  /// Throws [VisionAnalysisException] on non-2xx response.
  /// Throws [ResponseParsingException] on schema mismatch or malformed JSON.
  Future<List<ClothingItem>> _analyzeImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      'model': 'gpt-4o',
      'max_tokens': 1000,
      'temperature': 0.0,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _systemPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,$base64Image',
                'detail': 'high',
              },
            },
          ],
        },
      ],
    });

    final jwt = _jwtProvider();
    if (jwt == null || jwt.isEmpty) {
      throw const VisionAnalysisException('User not authenticated');
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
        body: body,
      );
    } on Exception catch (e) {
      throw VisionAnalysisException('Network error during vision analysis: $e');
    }

    if (response.statusCode == 429) {
      throw const GptLimitExceededException(
        'Hai raggiunto il limite mensile di analisi AI.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VisionAnalysisException(
        'OpenAI returned ${response.statusCode}: ${response.body}',
      );
    }

    return _parseOpenAiResponse(response.body);
  }

  // ── Response parsing ──────────────────────────────────────────────────────

  /// Extracts the assistant message content from the OpenAI response envelope
  /// and parses it into a list of [ClothingItem].
  ///
  /// Throws [ResponseParsingException] on any schema or JSON error.
  List<ClothingItem> _parseOpenAiResponse(String responseBody) {
    try {
      final envelope = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = envelope['choices'] as List<dynamic>;
      final content =
          (choices.first as Map<String, dynamic>)['message']['content']
              as String;

      // Pulizia di sicurezza nel caso GPT aggiunga markdown tipo ```json
      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsedList = jsonDecode(cleaned) as List<dynamic>;

      return parsedList
          .map((item) => ClothingItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ResponseParsingException {
      rethrow;
    } catch (e) {
      throw ResponseParsingException(
        'Could not parse OpenAI response: $e\nRaw body: $responseBody',
      );
    }
  }
}
