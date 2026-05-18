import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/clothing_analysis_result.dart';

// ── Custom Exceptions ─────────────────────────────────────────────────────────

sealed class ClothingAnalysisException implements Exception {
  final String message;
  const ClothingAnalysisException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the Remove.bg background-removal API returns a non-2xx status.
final class BackgroundRemovalException extends ClothingAnalysisException {
  const BackgroundRemovalException(super.message);
}

/// Thrown when the OpenAI Vision API returns a non-2xx status.
final class VisionAnalysisException extends ClothingAnalysisException {
  const VisionAnalysisException(super.message);
}

/// Thrown when the OpenAI response body cannot be parsed into
/// `ClothingAnalysisResult` (unexpected schema or malformed JSON).
final class ResponseParsingException extends ClothingAnalysisException {
  const ResponseParsingException(super.message);
}

/// Thrown when the user has reached their monthly GPT usage cap (HTTP 429).
final class GptLimitExceededException extends ClothingAnalysisException {
  const GptLimitExceededException(super.message);
}

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
- "baseColor": string (Primary color in Italian, e.g. "Nero", "Bianco", "Blu navy")
- "pattern": string (ONE OF: "Solid", "Striped", "Plaid", "Graphic", "Logo", "Floral", "Other")
- "coverage": string (ONE OF: "Short-sleeve", "Long-sleeve", "Sleeveless", "Shorts", "Full-length", "Cropped", "N/A")
- "fit": string (ONE OF: "Skinny", "Regular", "Oversize", "N/A")
- "warmth": integer (1 to 5: 1=canottiera/sandali, 2=t-shirt/sneakers, 3=felpa/jeans, 4=cappotto/stivali, 5=piumino/scarponi)
- "formality": string (ONE OF: "Loungewear", "Casual", "Smart Casual", "Business", "Formal")
- "activityTags": array of strings (ONLY from: ["Everyday", "Office", "Active", "Beach", "Evening Out", "Home"])
''';

  // final String _removeBgApiKey; // ← REMOVE.BG DISABILITATO
  final String _proxyUrl;
  final String _anonKey;
  final http.Client _client;
  final String? Function() _jwtProvider;

  AiClothingAnalyzerService({
    // required String removeBgApiKey, // ← REMOVE.BG DISABILITATO
    required String proxyUrl,
    required String anonKey,
    http.Client? client,
    String? Function()? jwtProvider,
  }) : // _removeBgApiKey = removeBgApiKey, // ← REMOVE.BG DISABILITATO
       _proxyUrl = proxyUrl,
       _anonKey = anonKey,
       _client = client ?? http.Client(),
       _jwtProvider = jwtProvider ?? (
           () => Supabase.instance.client.auth.currentSession?.accessToken
       );

  // ── Public orchestrators ──────────────────────────────────────────────────

  /// Analizza il file immagine passando direttamente a GPT-4o Vision
  /// (senza step di rimozione background).
  ///
  /// Throws a [ClothingAnalysisException] subclass on any failure.
  Future<List<ClothingItem>> processClothingItem(File imageFile) async {
    // REMOVE.BG DISABILITATO: si salta lo step di background removal
    // final Uint8List transparentPng = await _removeBackground(imageFile);
    // return (await _analyzeImage(transparentPng)).items;

    final Uint8List imageBytes = await imageFile.readAsBytes();
    return (await _analyzeImage(imageBytes)).items;
  }

  /// Stesso di [processClothingItem] ma restituisce anche i bytes dell'immagine
  /// e il raw JSON string dalla risposta OpenAI (utile per la sandbox UI).
  ///
  /// Throws a [ClothingAnalysisException] subclass on any failure.
  Future<
    ({Uint8List processedBytes, List<ClothingItem> result, String rawJson})
  >
  processWithIntermediateResult(File imageFile) async {
    // REMOVE.BG DISABILITATO: si usano i bytes originali al posto del PNG trasparente
    // final Uint8List processedBytes = await _removeBackground(imageFile);
    // final analyzed = await _analyzeImage(processedBytes);

    final Uint8List processedBytes = await imageFile.readAsBytes();
    final analyzed = await _analyzeImage(processedBytes);
    return (
      processedBytes: processedBytes,
      result: analyzed.items,
      rawJson: analyzed.rawJson,
    );
  }

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
  /// Returns both the parsed items and the raw cleaned JSON string for debugging.
  ///
  /// Throws [VisionAnalysisException] on non-2xx response.
  /// Throws [ResponseParsingException] on schema mismatch or malformed JSON.
  Future<({List<ClothingItem> items, String rawJson})> _analyzeImage(
    Uint8List imageBytes,
  ) async {
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
      throw const GptLimitExceededException('Hai raggiunto il limite mensile di analisi AI.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VisionAnalysisException(
        'OpenAI returned ${response.statusCode}: ${response.body}',
      );
    }

    return _parseOpenAiResponse(response.body);
  }

  // ── Response parsing ──────────────────────────────────────────────────────

  /// Extracts the assistant message content from the OpenAI response envelope,
  /// parses it into a list of [ClothingItem], and returns the cleaned JSON string.
  ///
  /// Throws [ResponseParsingException] on any schema or JSON error.
  ({List<ClothingItem> items, String rawJson}) _parseOpenAiResponse(
    String responseBody,
  ) {
    try {
      final envelope = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = envelope['choices'] as List<dynamic>;
      final content =
          (choices.first as Map<String, dynamic>)['message']['content']
              as String;

      // Pulizia di sicurezza nel caso GPT aggiunga markdown tipo ```json
      final rawJson = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsedList = jsonDecode(rawJson) as List<dynamic>;

      final items = parsedList
          .map((item) => ClothingItem.fromJson(item as Map<String, dynamic>))
          .toList();

      return (items: items, rawJson: rawJson);
    } on ResponseParsingException {
      rethrow;
    } catch (e) {
      throw ResponseParsingException(
        'Could not parse OpenAI response: $e\nRaw body: $responseBody',
      );
    }
  }
}
