import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../ai_input/model/clothing_analysis_result.dart';
import 'clothing_taxonomy.dart';

/// I dettagli modificabili di un capo, letti da e riscritti in un
/// [ClothingAnalysisResult] (e quindi in `items.ai_metadata`).
@immutable
class ClothingDetails {
  final String subCategory;

  /// Colore di base; null se vuoto o 'N/A'.
  final String? color;
  final int warmth;
  final int waterResistance;
  final String formality;

  /// Usi (tag di attività), come insieme.
  final Set<String> uses;

  const ClothingDetails({
    required this.subCategory,
    required this.color,
    required this.warmth,
    required this.waterResistance,
    required this.formality,
    required this.uses,
  });

  factory ClothingDetails.of(ClothingAnalysisResult r) {
    final colorValue = r.baseColor.trim();
    final hasColor = colorValue.isNotEmpty && colorValue.toLowerCase() != 'n/a';
    return ClothingDetails(
      subCategory: r.subCategory,
      color: hasColor ? colorValue : null,
      warmth: r.warmth,
      waterResistance: r.waterResistance,
      formality: r.formality,
      uses: r.activityTags.toSet(),
    );
  }

  /// [clearColor] riporta il colore a null (copyWith con `color: null` non
  /// distinguerebbe "non cambiare" da "cancella").
  ClothingDetails copyWith({
    String? subCategory,
    String? color,
    bool clearColor = false,
    int? warmth,
    int? waterResistance,
    String? formality,
    Set<String>? uses,
  }) {
    return ClothingDetails(
      subCategory: subCategory ?? this.subCategory,
      color: clearColor ? null : (color ?? this.color),
      warmth: warmth ?? this.warmth,
      waterResistance: waterResistance ?? this.waterResistance,
      formality: formality ?? this.formality,
      uses: uses ?? this.uses,
    );
  }

  /// Riscrive i campi su [r]; cambia anche `category` se la sottocategoria è
  /// nota. Ogni altra chiave ed `extras` restano come sono.
  ClothingAnalysisResult applyTo(ClothingAnalysisResult r) {
    return r.copyWith(
      subCategory: subCategory,
      baseColor: color ?? 'N/A',
      warmth: warmth,
      formality: formality,
      activityTags: [
        for (final tag in kActivityTags)
          if (uses.contains(tag)) tag,
      ],
      category: clothingCategoryOf(subCategory) ?? r.category,
      extras: {...r.extras, 'waterResistance': waterResistance},
    );
  }

  /// Nomi dei campi cambiati rispetto a [before], per l'evento analytics.
  List<String> changedFields(ClothingDetails before) {
    return [
      if (subCategory != before.subCategory) 'subCategory',
      if (_colorKey(color) != _colorKey(before.color)) 'baseColor',
      if (warmth != before.warmth) 'warmth',
      if (waterResistance != before.waterResistance) 'waterResistance',
      if (formality != before.formality) 'formality',
      if (!setEquals(uses, before.uses)) 'activityTags',
    ];
  }

  static String _colorKey(String? color) => (color ?? '').trim().toLowerCase();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClothingDetails &&
        other.subCategory == subCategory &&
        other.color == color &&
        other.warmth == warmth &&
        other.waterResistance == waterResistance &&
        other.formality == formality &&
        setEquals(other.uses, uses);
  }

  @override
  int get hashCode => Object.hash(
    subCategory,
    color,
    warmth,
    waterResistance,
    formality,
    Object.hashAllUnordered(uses),
  );
}

/// Lettura comoda da `ItemModel.aiMetadata`: null se assente, non leggibile
/// (anche per un tipo inatteso), o se il JSON dice che non è un capo.
ClothingAnalysisResult? clothingFromMetadata(String? aiMetadata) {
  if (aiMetadata == null || aiMetadata.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(aiMetadata);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final json = Map<String, dynamic>.from(decoded);
  if (json['category'] == 'Not Clothing') return null;
  // Un tipo inatteso (es. warmth decimale) non deve far cadere la scheda:
  // senza dettagli leggibili la sezione semplicemente non compare.
  try {
    return ClothingAnalysisResult.fromJson(json);
  } on TypeError {
    return null;
  }
}
