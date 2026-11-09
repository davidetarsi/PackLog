import 'package:flutter/foundation.dart';

import '../../items/model/clothing_details.dart';
import '../model/ai_import_state.dart';
import '../model/clothing_analysis_result.dart';

/// Com'è andata una scansione al salvataggio, per `ai_items_saved`. Solo
/// conteggi e sottocategorie della tassonomia, mai i nomi dei capi.
typedef ScanSaveStats = ({
  int found,
  int saved,
  int excluded,
  int renamed,
  int detailsEdited,
  int photos,
  List<String> excludedTypes,
  List<String> renamedTypes,
});

/// [analyzed]: i capi come li ha letti l'analisi, per (gruppo, posizione).
/// I tipi (`*Types`) sono quelli dell'analisi, ordinati, con ripetizioni.
ScanSaveStats scanSaveStats(
  AiImportState state,
  Map<(int, int), ClothingAnalysisResult> analyzed,
) {
  var found = 0, saved = 0, renamed = 0, detailsEdited = 0;
  final excludedTypes = <String>[];
  final renamedTypes = <String>[];
  for (var g = 0; g < state.photoGroups.length; g++) {
    final group = state.photoGroups[g];
    for (var i = 0; i < group.results.length; i++) {
      found++;
      final result = group.results[i];
      final original = analyzed[(g, i)] ?? result;
      if (group.excluded.contains(i)) {
        excludedTypes.add(original.subCategory);
        continue;
      }
      saved++;
      if (result.name.trim() != original.name.trim()) {
        renamed++;
        renamedTypes.add(original.subCategory);
      }
      final changed = ClothingDetails.of(
        result,
      ).changedFields(ClothingDetails.of(original));
      if (changed.isNotEmpty) detailsEdited++;
    }
  }
  return (
    found: found,
    saved: saved,
    excluded: excludedTypes.length,
    renamed: renamed,
    detailsEdited: detailsEdited,
    photos: state.photoGroups.length,
    excludedTypes: excludedTypes..sort(),
    renamedTypes: renamedTypes..sort(),
  );
}

/// Cosa ha fatto l'utente dei dubbi di Jev su un capo, per
/// `ai_scan_doubt_resolved`. Liste di nomi di campo, mai i valori.
typedef DoubtOutcome = ({
  List<String> doubtFields,
  List<String> choseJev,
  List<String> keptGpt,
  List<String> otherValue,
  List<String> correctedWithoutDoubt,
  String subCategory,
});

/// Null se il capo non aveva dubbi e l'utente non ha cambiato nulla. Per ogni
/// dubbio (fra i campi che l'app conosce): valore finale uguale a quello di
/// GPT → [DoubtOutcome.keptGpt], a quello di Jev → `choseJev`, altro →
/// `otherValue`. I campi cambiati senza dubbio → `correctedWithoutDoubt`.
DoubtOutcome? doubtOutcome(
  ClothingAnalysisResult original,
  ClothingAnalysisResult saved,
) {
  final before = ClothingDetails.of(original);
  final after = ClothingDetails.of(saved);
  final doubtFields = [
    for (final d in original.doubts)
      if (clothingFieldOfDoubt(d) != null) d,
  ];
  final changed = after.changedFields(before);
  if (doubtFields.isEmpty && changed.isEmpty) return null;

  final choseJev = <String>[];
  final keptGpt = <String>[];
  final otherValue = <String>[];
  for (final field in doubtFields) {
    final value = _valueOf(field, after);
    if (_same(value, _valueOf(field, before))) {
      keptGpt.add(field);
    } else if (original.doubtJev.containsKey(field) &&
        _same(value, _normalize(field, original.doubtJev[field]))) {
      choseJev.add(field);
    } else {
      otherValue.add(field);
    }
  }
  return (
    doubtFields: doubtFields,
    choseJev: choseJev,
    keptGpt: keptGpt,
    otherValue: otherValue,
    correctedWithoutDoubt: [
      for (final f in changed)
        if (!doubtFields.contains(f)) f,
    ],
    subCategory: original.subCategory,
  );
}

/// Il valore di [field] (chiave di `ai_metadata`) in [d], nella stessa forma
/// di [_normalize].
Object? _valueOf(String field, ClothingDetails d) => switch (field) {
  'subCategory' => d.subCategory,
  'baseColor' => _colorKey(d.color),
  'warmth' => d.warmth,
  'waterResistance' => d.waterResistance,
  'formality' => d.formality,
  'activityTags' => d.uses,
  _ => null,
};

/// Un valore grezzo di Jev nella forma di [_valueOf]: numeri interi, colore
/// minuscolo senza spazi, usi come insieme.
Object? _normalize(String field, Object? raw) => switch (field) {
  'baseColor' => _colorKey(raw is String ? raw : null),
  'warmth' || 'waterResistance' => raw is num ? raw.toInt() : null,
  'activityTags' => raw is List ? raw.whereType<String>().toSet() : null,
  _ => raw,
};

String _colorKey(String? color) => (color ?? '').trim().toLowerCase();

bool _same(Object? a, Object? b) =>
    a is Set && b is Set ? setEquals(a, b) : a == b;
