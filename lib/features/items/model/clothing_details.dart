import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../ai_input/model/clothing_analysis_result.dart';
import 'item_model.dart';
import 'clothing_taxonomy.dart';

/// I dettagli modificabili di un capo, letti da e riscritti in un
/// [ClothingAnalysisResult] (e quindi in `items.ai_metadata`).
@immutable
class ClothingDetails {
  /// Tipo; null se l'utente non l'ha ancora scelto.
  final String? subCategory;

  /// Colore di base; null se vuoto o 'N/A'.
  final String? color;
  final int? warmth;
  final int? waterResistance;
  final String? formality;

  /// Usi (tag di attività), come insieme. Vuoto = nessuno.
  final Set<String> uses;

  const ClothingDetails({
    this.subCategory,
    this.color,
    this.warmth,
    this.waterResistance,
    this.formality,
    this.uses = const <String>{},
  });

  /// Nessun dettaglio: è quello di un oggetto aggiunto a mano.
  static const ClothingDetails empty = ClothingDetails();

  factory ClothingDetails.of(ClothingAnalysisResult r) {
    return ClothingDetails(
      subCategory: r.subCategory,
      color: _textOf(r.baseColor),
      warmth: r.warmth,
      waterResistance: r.waterResistance,
      formality: r.formality,
      uses: r.activityTags.toSet(),
    );
  }

  /// I dettagli scritti in [m] (la mappa di `items.ai_metadata`). Non usa i
  /// default di [ClothingAnalysisResult.fromJson]: una chiave assente resta
  /// null, cioè "da scegliere".
  factory ClothingDetails.fromMetadata(Map<String, dynamic> m) {
    final warmth = m['warmth'];
    final water = m['waterResistance'];
    final tags = m['activityTags'];
    return ClothingDetails(
      subCategory: _textOf(m['subCategory']),
      color: _textOf(m['baseColor']),
      warmth: warmth is num ? warmth.toInt() : null,
      waterResistance: water is num ? water.toInt() : null,
      formality: _textOf(m['formality']),
      uses: tags is List
          ? <String>{
              for (final tag in tags)
                if (tag is String) tag,
            }
          : const <String>{},
    );
  }

  /// Un valore di testo senza spazi; null se manca, è vuoto o 'N/A' (il server
  /// scrive 'N/A' quando non riconosce il valore).
  static String? _textOf(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    final hasColor = value.isNotEmpty && value.toLowerCase() != 'n/a';
    return hasColor ? value : null;
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

  /// Riscrive su [r] i campi che hanno un valore; cambia anche `category` se
  /// la sottocategoria è nota. Un campo null resta quello di [r], tranne il
  /// colore: senza colore si scrive 'N/A'. Ogni altra chiave ed `extras`
  /// restano come sono.
  ClothingAnalysisResult applyTo(ClothingAnalysisResult r) {
    final type = subCategory;
    return r.copyWith(
      subCategory: type ?? r.subCategory,
      baseColor: color ?? 'N/A',
      warmth: warmth ?? r.warmth,
      formality: formality ?? r.formality,
      activityTags: [
        for (final tag in kActivityTags)
          if (uses.contains(tag)) tag,
      ],
      category: type == null
          ? r.category
          : (clothingCategoryOf(type) ?? r.category),
      extras: {
        ...r.extras,
        if (waterResistance != null) 'waterResistance': waterResistance,
      },
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

/// La chiave in `items.ai_metadata` del campo [f]: la stessa del risultato
/// dell'AI, e quella usata in `userFields`.
String metadataKeyOf(ClothingField f) => switch (f) {
  ClothingField.type => 'subCategory',
  ClothingField.color => 'baseColor',
  ClothingField.warmth => 'warmth',
  ClothingField.waterResistance => 'waterResistance',
  ClothingField.formality => 'formality',
  ClothingField.uses => 'activityTags',
};

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
