/// Alias usato dal service per chiarire che ogni istanza rappresenta
/// un singolo capo d'abbigliamento identificato nell'immagine.
typedef ClothingItem = ClothingAnalysisResult;

/// Immutable result returned by the AI clothing analysis pipeline.
///
/// Contains deep metadata fields designed for the Smart Packing Recommender
/// algorithm. Parsed from the raw JSON produced by GPT-4o Vision. Every field
/// has a safe default so that a partial / malformed response never throws at
/// the model level.
///
/// [calculatedVersatility] is derived deterministically from the object's
/// properties rather than being hallucinated by the AI.
class ClothingAnalysisResult {
  final String name;
  final String category;
  final String baseColor;
  final String colorTone;
  final List<String> weather;
  final String coverage;
  final String pattern;
  final int formality;
  final List<String> activityTags;

  const ClothingAnalysisResult({
    required this.name,
    required this.category,
    required this.baseColor,
    required this.colorTone,
    required this.weather,
    required this.coverage,
    required this.pattern,
    required this.formality,
    required this.activityTags,
  });

  factory ClothingAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ClothingAnalysisResult(
      name: json['name'] as String? ?? 'Sconosciuto',
      category: json['category'] as String? ?? '',
      baseColor: json['baseColor'] as String? ?? '',
      colorTone: json['colorTone'] as String? ?? '',
      weather: (json['weather'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      coverage: json['coverage'] as String? ?? '',
      pattern: json['pattern'] as String? ?? '',
      formality: json['formality'] as int? ?? 5,
      activityTags: (json['activityTags'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ClothingAnalysisResult copyWith({
    String? name,
    String? category,
    String? baseColor,
    String? colorTone,
    List<String>? weather,
    String? coverage,
    String? pattern,
    int? formality,
    List<String>? activityTags,
  }) {
    return ClothingAnalysisResult(
      name: name ?? this.name,
      category: category ?? this.category,
      baseColor: baseColor ?? this.baseColor,
      colorTone: colorTone ?? this.colorTone,
      weather: weather ?? this.weather,
      coverage: coverage ?? this.coverage,
      pattern: pattern ?? this.pattern,
      formality: formality ?? this.formality,
      activityTags: activityTags ?? this.activityTags,
    );
  }

  // ── Derived score ─────────────────────────────────────────────────────────

  /// Deterministic versatility score (1–5) calculated from the item's own
  /// properties. Replaces the AI-hallucinated `versatility` field.
  int get calculatedVersatility {
    // Sport/sleep gear is niche by definition.
    if (activityTags.contains('Sports') || activityTags.contains('Sleeping') || activityTags.contains('Hiking')) {
      return 1;
    }

    var score = 3;

    // Very casual or very formal items pair with fewer outfits.
    if (formality >= 8 || formality <= 2) {
      score -= 1;
    } else if (formality >= 4 && formality <= 6) {
      // Mid-formality items are the easiest to mix-and-match.
      score += 1;
    }

    // Neutral/earthy tones and classic colours mix with almost anything.
    if (baseColor == 'Nero' ||
        baseColor == 'Bianco' ||
        colorTone == 'Neutral') {
      score += 1;
    }

    // Prints and graphics constrain outfit combinations.
    if (pattern != 'Solid') {
      score -= 1;
    }

    return score.clamp(1, 5);
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'baseColor': baseColor,
        'colorTone': colorTone,
        'weather': weather,
        'coverage': coverage,
        'pattern': pattern,
        'formality': formality,
        'activityTags': activityTags,
      };

  @override
  String toString() => 'ClothingAnalysisResult('
      'name: $name, category: $category, baseColor: $baseColor, '
      'colorTone: $colorTone, weather: $weather, coverage: $coverage, '
      'pattern: $pattern, formality: $formality, '
      'calculatedVersatility: $calculatedVersatility, activityTags: $activityTags)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ClothingAnalysisResult) return false;
    if (name != other.name) return false;
    if (category != other.category) return false;
    if (baseColor != other.baseColor) return false;
    if (colorTone != other.colorTone) return false;
    if (coverage != other.coverage) return false;
    if (pattern != other.pattern) return false;
    if (formality != other.formality) return false;
    if (weather.length != other.weather.length) return false;
    for (var i = 0; i < weather.length; i++) {
      if (weather[i] != other.weather[i]) return false;
    }
    if (activityTags.length != other.activityTags.length) return false;
    for (var i = 0; i < activityTags.length; i++) {
      if (activityTags[i] != other.activityTags[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        name,
        category,
        baseColor,
        colorTone,
        coverage,
        pattern,
        formality,
        Object.hashAll(weather),
        Object.hashAll(activityTags),
      );
}
