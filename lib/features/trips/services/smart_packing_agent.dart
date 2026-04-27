import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/config/app_config.dart';
import '../../items/model/item_model.dart';
import '../../poc_ai/models/clothing_analysis_result.dart';

part 'smart_packing_agent.g.dart';

// ── Domain model ─────────────────────────────────────────────────────────────

/// A single item recommendation produced by the AI packing agent.
///
/// [itemId] matches the exact id from the pre-screened inventory buckets.
/// [motivation] is a concise Italian sentence explaining the choice.
class SmartPackingRecommendation {
  final String itemId;
  final int quantityToTake;
  final String motivation;

  const SmartPackingRecommendation({
    required this.itemId,
    required this.quantityToTake,
    required this.motivation,
  });

  factory SmartPackingRecommendation.fromJson(Map<String, dynamic> json) {
    return SmartPackingRecommendation(
      itemId: json['itemId'] as String? ?? '',
      quantityToTake: (json['quantityToTake'] as num?)?.toInt() ?? 1,
      motivation: json['motivation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'quantityToTake': quantityToTake,
        'motivation': motivation,
      };

  @override
  String toString() =>
      'SmartPackingRecommendation(itemId: $itemId, quantityToTake: $quantityToTake, motivation: $motivation)';
}

// ── Service ───────────────────────────────────────────────────────────────────

/// AI Orchestrator that calls GPT-4o-mini to produce a curated packing list
/// from pre-screened inventory buckets and deterministic quotas.
///
/// Inject a custom [http.Client] for testing; defaults to [http.Client()].
class SmartPackingAgent {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';

  final String _apiKey;
  final http.Client _client;

  SmartPackingAgent({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  /// Generates a curated packing list from the available inventory.
  ///
  /// Returns a list of [SmartPackingRecommendation]s with the AI's item
  /// selections and motivations. The list may be empty if the AI returns no
  /// valid items.
  ///
  /// Throws on HTTP errors, timeouts or unparseable responses so that the
  /// caller can apply graceful degradation.
  Future<List<SmartPackingRecommendation>> generatePackingList({
    required String destination,
    required int tripDurationDays,
    required List<String> weatherTags,
    required Map<String, int> quotas,
    required List<ItemModel> wardrobeBucket,
    required String pastTripsJson,
  }) async {
    final prompt = _buildSystemPrompt(
      destination: destination,
      tripDurationDays: tripDurationDays,
      weatherTags: weatherTags,
      quotas: quotas,
      wardrobeBucket: wardrobeBucket,
      pastTripsJson: pastTripsJson,
    );

    debugPrint('[SmartPackingAgent] Calling GPT-4o-mini for $destination');

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'temperature': 0.0,
        'messages': [
          {'role': 'system', 'content': prompt},
          {
            'role': 'user',
            'content':
                'Generate the packing list now. Respond ONLY with the raw JSON array.',
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        '[SmartPackingAgent] HTTP ${response.statusCode}: ${response.body}',
      );
    }

    return _parseResponse(response.body);
  }

  // ── Prompt builder ────────────────────────────────────────────────────────

  String _buildSystemPrompt({
    required String destination,
    required int tripDurationDays,
    required List<String> weatherTags,
    required Map<String, int> quotas,
    required List<ItemModel> wardrobeBucket,
    required String pastTripsJson,
  }) {
    final quotaLines = quotas.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');

    final wardrobeJson =
        jsonEncode(wardrobeBucket.map(_itemToJson).toList());

    return '''
You are an expert travel stylist and practical packer. Your task is to select the perfect wardrobe items for a trip.
DESTINATION: $destination ($tripDurationDays days).
WEATHER: ${weatherTags.join(', ')}.

PAST TRIPS / USER PREFERENCES:
$pastTripsJson
(If this list is not empty, CRITICALLY prioritize selecting these exact items to match the user's personal style, provided they fit the current weather and quotas).

CONSTRAINTS:
1. WARDROBE QUOTAS: You MUST strictly respect these quantities:
$quotaLines
The SUM of 'quantityToTake' for the items you select in each category MUST exactly match the required quota. You cannot take more than the 'availableQty' of any single item.
2. VERSATILITY & STYLE: Favor items with high 'calculatedVersatility'. Ensure colors match well to create mix-and-match outfits.
3. CRITICAL CHECK: Before generating the JSON, verify that the total count of items per category exactly matches the WARDROBE QUOTAS.

AVAILABLE WARDROBE: 
$wardrobeJson

Respond ONLY with a raw JSON array of objects. No markdown, no code fences.
Each object must have EXACTLY these keys:
- "itemId": string (The exact id from the provided AVAILABLE WARDROBE list)
- "quantityToTake": integer (How many units of this specific item to pack)
- "motivation": string (A short, 1-sentence explanation in Italian of WHY you chose this, e.g., "L'hai già usata con successo in un viaggio simile ed è ottima per il caldo.")
''';
  }

  // ── Response parser ───────────────────────────────────────────────────────

  List<SmartPackingRecommendation> _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('[SmartPackingAgent] Empty choices array');
    }

    final content =
        (choices.first as Map<String, dynamic>)['message']['content']
            as String?;
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('[SmartPackingAgent] Empty content field');
    }

    // Strip optional markdown code fences that the model might still emit.
    final cleaned = content
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    final parsed = jsonDecode(cleaned);
    if (parsed is! List) {
      throw FormatException(
        '[SmartPackingAgent] Expected JSON array, got ${parsed.runtimeType}',
      );
    }

    return parsed
        .whereType<Map<String, dynamic>>()
        .map(SmartPackingRecommendation.fromJson)
        .where((r) => r.itemId.isNotEmpty)
        .toList();
  }

  // ── Item serialisation ────────────────────────────────────────────────────

  /// Converts an [ItemModel] to a token-minimal JSON map for the GPT prompt.
  ///
  /// Only includes fields the AI needs for outfit decisions: identity,
  /// category, colour pairing data, weather compatibility, formality level,
  /// and the deterministic versatility score. Names, patterns, and other
  /// display-only fields are excluded to reduce prompt dilution.
  Map<String, dynamic> _itemToJson(ItemModel item) {
    final meta = item.aiMetadata;
    final result = <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'category': item.category.name,
      'availableQty': item.quantity ?? 1,
    };

    if (meta != null) {
      if (meta['weather'] != null) result['weather'] = meta['weather'];
      if (meta['activityTags'] != null) {
        result['activityTags'] = meta['activityTags'];
      }
      if (meta['baseColor'] != null) result['baseColor'] = meta['baseColor'];
      if (meta['colorTone'] != null) result['colorTone'] = meta['colorTone'];
      if (meta['formality'] != null) result['formality'] = meta['formality'];
      try {
        final analysisResult = ClothingAnalysisResult.fromJson(meta);
        result['calculatedVersatility'] = analysisResult.calculatedVersatility;
      } catch (_) {}
    }

    return result;
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

@riverpod
SmartPackingAgent smartPackingAgent(Ref ref) {
  return SmartPackingAgent(apiKey: AppConfig.openAi);
}
