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
  final String motivation;

  const SmartPackingRecommendation({
    required this.itemId,
    required this.motivation,
  });

  factory SmartPackingRecommendation.fromJson(Map<String, dynamic> json) {
    return SmartPackingRecommendation(
      itemId: json['itemId'] as String? ?? '',
      motivation: json['motivation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'motivation': motivation,
      };

  @override
  String toString() =>
      'SmartPackingRecommendation(itemId: $itemId, motivation: $motivation)';
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
    required List<ItemModel> essentialsBucket,
  }) async {
    final prompt = _buildSystemPrompt(
      destination: destination,
      tripDurationDays: tripDurationDays,
      weatherTags: weatherTags,
      quotas: quotas,
      wardrobeBucket: wardrobeBucket,
      essentialsBucket: essentialsBucket,
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
    required List<ItemModel> essentialsBucket,
  }) {
    final quotaLines = quotas.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');

    final wardrobeJson =
        jsonEncode(wardrobeBucket.map(_itemToJson).toList());
    final essentialsJson =
        jsonEncode(essentialsBucket.map(_itemToJson).toList());

    return '''
You are an expert travel stylist and practical packer. Your task is to select the perfect items for a trip.
DESTINATION: $destination ($tripDurationDays days).
WEATHER: ${weatherTags.join(', ')}.

CONSTRAINTS:
1. WARDROBE QUOTAS: You MUST strictly respect these quantities:
$quotaLines
2. ESSENTIALS: Pick all strictly necessary tech, toiletries, and documents for the days.
3. VERSATILITY: Favor items with high 'calculatedVersatility'. Ensure colors match well.

AVAILABLE WARDROBE: $wardrobeJson

AVAILABLE ESSENTIALS: $essentialsJson

Respond ONLY with a raw JSON array of objects. No markdown, no code fences.
Each object must have EXACTLY these keys:
- "itemId": string (The exact id from the provided lists above)
- "motivation": string (A short, 1-sentence explanation in Italian of WHY you chose this, e.g., "Ottima per la pioggia e abbinabile con i jeans.")
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

  /// Converts an [ItemModel] to a minimal JSON map for the GPT prompt.
  ///
  /// Includes AI metadata fields (weather, activityTags, calculatedVersatility)
  /// when available so the model can make informed outfit decisions.
  Map<String, dynamic> _itemToJson(ItemModel item) {
    final meta = item.aiMetadata;
    final result = <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'category': item.category.name,
    };

    if (meta != null) {
      if (meta['weather'] != null) result['weather'] = meta['weather'];
      if (meta['activityTags'] != null) {
        result['activityTags'] = meta['activityTags'];
      }
      if (meta['baseColor'] != null) result['baseColor'] = meta['baseColor'];
      if (meta['colorTone'] != null) result['colorTone'] = meta['colorTone'];
      // Include calculated (non-hallucinated) versatility score.
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
