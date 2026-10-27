import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../ai_input/model/clothing_analysis_result.dart';
import 'item_model.dart';
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

/// Un dettaglio della scheda di un oggetto.
enum ClothingField { type, color, warmth, waterResistance, formality, uses }

/// Il campo di un dubbio del server ('subCategory', 'warmth', …); null per
/// un nome che l'app non conosce.
ClothingField? clothingFieldOfDoubt(String doubt) => switch (doubt) {
  'subCategory' => ClothingField.type,
  'baseColor' => ClothingField.color,
  'warmth' => ClothingField.warmth,
  'waterResistance' => ClothingField.waterResistance,
  'formality' => ClothingField.formality,
  'activityTags' => ClothingField.uses,
  _ => null,
};

/// I dettagli che hanno senso per un oggetto di [category]:
/// - vestiti: tutti;
/// - varie: tipo e colore, più l'impermeabilità per borse e zaini (calore,
///   stile e usi non dicono niente di uno zaino o di un paio di occhiali);
/// - toiletries ed elettronica: nessuno.
Set<ClothingField> clothingFieldsFor(
  ItemCategory category,
  String subCategory,
) => switch (category) {
  ItemCategory.vestiti => ClothingField.values.toSet(),
  ItemCategory.varie => {
    ClothingField.type,
    ClothingField.color,
    if (subCategory == 'Bag') ClothingField.waterResistance,
  },
  ItemCategory.toiletries || ItemCategory.elettronica => const {},
};

/// I dubbi di [doubts] che riguardano un campo fra [fields]: gli altri non
/// si vedono e quindi non si possono controllare. Un nome sconosciuto resta.
List<String> visibleDoubts(
  Iterable<String> doubts,
  Set<ClothingField> fields,
) => [
  for (final doubt in doubts)
    if (clothingFieldOfDoubt(doubt) == null ||
        fields.contains(clothingFieldOfDoubt(doubt)))
      doubt,
];
