/// Alias usato dal service per chiarire che ogni istanza rappresenta
/// un singolo capo d'abbigliamento identificato nell'immagine.
typedef ClothingItem = ClothingAnalysisResult;

class ClothingAnalysisResult {
  final String name;
  final String category;
  final String subCategory;
  final String baseColor;
  final String pattern;
  final String coverage;
  final String fit;
  final int warmth;
  final String formality;
  final List<String> activityTags;

  const ClothingAnalysisResult({
    required this.name,
    required this.category,
    this.subCategory = '',
    required this.baseColor,
    required this.pattern,
    required this.coverage,
    required this.fit,
    required this.warmth,
    required this.formality,
    required this.activityTags,
  });

  factory ClothingAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ClothingAnalysisResult(
      name: json['name'] as String? ?? 'Sconosciuto',
      category: json['category'] as String? ?? '',
      subCategory: json['subCategory'] as String? ?? '',
      baseColor: json['baseColor'] as String? ?? '',
      pattern: json['pattern'] as String? ?? '',
      coverage: json['coverage'] as String? ?? '',
      fit: json['fit'] as String? ?? 'N/A',
      warmth: (json['warmth'] as int?) ?? 3,
      formality: json['formality'] as String? ?? 'Casual',
      activityTags: (json['activityTags'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }

  ClothingAnalysisResult copyWith({
    String? name,
    String? category,
    String? subCategory,
    String? baseColor,
    String? pattern,
    String? coverage,
    String? fit,
    int? warmth,
    String? formality,
    List<String>? activityTags,
  }) {
    return ClothingAnalysisResult(
      name: name ?? this.name,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      baseColor: baseColor ?? this.baseColor,
      pattern: pattern ?? this.pattern,
      coverage: coverage ?? this.coverage,
      fit: fit ?? this.fit,
      warmth: warmth ?? this.warmth,
      formality: formality ?? this.formality,
      activityTags: activityTags ?? this.activityTags,
    );
  }

  int get calculatedVersatility {
    var score = 3;

    if (category == 'Shoes' || category == 'Accessory') {
      score -= 1;
    }

    if (warmth <= 1 || warmth >= 5) {
      score -= 1;
    }

    if (fit == 'Oversize') {
      score -= 1;
    }

    if (formality == 'Formal' ||
        formality == 'Business' ||
        formality == 'Loungewear') {
      score -= 1;
    } else if (formality == 'Casual' || formality == 'Smart Casual') {
      score += 1;
    }

    if (baseColor == 'Nero' ||
        baseColor == 'Bianco' ||
        baseColor == 'Grigio' ||
        baseColor == 'Blu navy') {
      score += 1;
    }

    if (pattern != 'Solid') {
      score -= 1;
    }

    return score.clamp(1, 5);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'subCategory': subCategory,
    'baseColor': baseColor,
    'pattern': pattern,
    'coverage': coverage,
    'fit': fit,
    'warmth': warmth,
    'formality': formality,
    'activityTags': activityTags,
  };

  @override
  String toString() =>
      'ClothingAnalysisResult('
      'name: $name, category: $category, subCategory: $subCategory, '
      'baseColor: $baseColor, pattern: $pattern, coverage: $coverage, fit: $fit, '
      'warmth: $warmth, formality: $formality, '
      'calculatedVersatility: $calculatedVersatility, activityTags: $activityTags)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ClothingAnalysisResult) return false;
    if (name != other.name) return false;
    if (category != other.category) return false;
    if (subCategory != other.subCategory) return false;
    if (baseColor != other.baseColor) return false;
    if (pattern != other.pattern) return false;
    if (coverage != other.coverage) return false;
    if (fit != other.fit) return false;
    if (warmth != other.warmth) return false;
    if (formality != other.formality) return false;
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
    subCategory,
    baseColor,
    pattern,
    coverage,
    fit,
    warmth,
    formality,
    Object.hashAll(activityTags),
  );
}
