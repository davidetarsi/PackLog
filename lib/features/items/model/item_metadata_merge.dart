import 'dart:convert';

import 'clothing_details.dart';
import 'clothing_taxonomy.dart';

/// Chiave dei metadati con i nomi dei campi scelti dall'utente (quelli di
/// [metadataKeyOf]). L'AI non li cambia.
const kUserFieldsKey = 'userFields';

/// `true` quando i metadati contengono solo scelte dell'utente e la risposta
/// dell'AI non è ancora arrivata.
const kAiPendingKey = 'aiPending';

/// La mappa di [aiMetadata]; null se manca, è vuota, non si legge o non è
/// una mappa.
Map<String, dynamic>? _readMap(String? aiMetadata) {
  if (aiMetadata == null || aiMetadata.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(aiMetadata);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  return Map<String, dynamic>.from(decoded);
}

/// I campi che l'utente ha scelto, da `userFields`; vuoto se manca o non si
/// legge. I valori che non sono stringhe si ignorano.
Set<String> userFieldsOf(String? aiMetadata) {
  final raw = _readMap(aiMetadata)?[kUserFieldsKey];
  if (raw is! List) return <String>{};
  return <String>{
    for (final name in raw)
      if (name is String) name,
  };
}

/// Se i metadati vanno ancora completati dall'AI: mancano, non si leggono, o
/// hanno `aiPending`.
bool needsAiMetadata(String? aiMetadata) {
  final map = _readMap(aiMetadata);
  return map == null || map[kAiPendingKey] == true;
}

/// I metadati di [current] con i campi [touched] scritti da [details]. Sono
/// scelte dell'utente: si segnano in `userFields`, e l'AI non le cambia. Gli
/// altri campi restano come sono.
///
/// Un campo toccato senza valore si toglie, tranne il colore, che diventa
/// 'N/A'. Toccato il tipo, si scrive anche la categoria, se è nota. Se
/// [current] manca o non si legge, il risultato ha `aiPending: true`.
String withUserDetails({
  String? current,
  required ClothingDetails details,
  required Set<ClothingField> touched,
}) {
  final readable = _readMap(current);
  final json = readable ?? <String, dynamic>{};
  final userFields = <String>{...userFieldsOf(current)};

  for (final field in touched) {
    userFields.add(metadataKeyOf(field));
    switch (field) {
      case ClothingField.type:
        _putOrRemove(json, 'subCategory', details.subCategory);
        final type = details.subCategory;
        if (type != null) {
          final category = clothingCategoryOf(type);
          if (category != null) json['category'] = category;
        }
      case ClothingField.color:
        json['baseColor'] = details.color ?? 'N/A';
      case ClothingField.warmth:
        _putOrRemove(json, 'warmth', details.warmth);
      case ClothingField.waterResistance:
        _putOrRemove(json, 'waterResistance', details.waterResistance);
      case ClothingField.formality:
        _putOrRemove(json, 'formality', details.formality);
      case ClothingField.uses:
        json['activityTags'] = [
          for (final tag in kActivityTags)
            if (details.uses.contains(tag)) tag,
        ];
    }
  }

  if (userFields.isEmpty) {
    json.remove(kUserFieldsKey);
  } else {
    json[kUserFieldsKey] = userFields.toList();
  }
  if (readable == null) json[kAiPendingKey] = true;
  return jsonEncode(json);
}

/// I metadati di [current] con `aiPending: true`: i valori e `userFields`
/// restano, ma la scheda dell'AI conta di nuovo come da completare (vedi
/// [needsAiMetadata]). Se [current] manca o non si legge resta com'è: è già da
/// completare.
String? withAiPending(String? current) {
  final map = _readMap(current);
  if (map == null) return current;
  map[kAiPendingKey] = true;
  return jsonEncode(map);
}

void _putOrRemove(Map<String, dynamic> json, String key, Object? value) {
  if (value == null) {
    json.remove(key);
  } else {
    json[key] = value;
  }
}

/// Unisce la risposta dell'AI [ai] con i metadati correnti [current], campo
/// per campo: i campi in `userFields` restano quelli di [current] (o si tolgono
/// se [current] non li ha); la categoria resta quella di [current] quando il
/// tipo è dell'utente. Le chiavi di [current] che l'AI non ha restano;
/// `aiPending` sparisce.
///
/// Senza [current], o se non si legge, il risultato è [ai] così com'è.
String mergeAiMetadata({String? current, required Map<String, dynamic> ai}) {
  final old = _readMap(current);
  if (old == null) return jsonEncode(ai);

  final merged = Map<String, dynamic>.from(ai);
  for (final entry in old.entries) {
    if (entry.key == kAiPendingKey || entry.key == kUserFieldsKey) continue;
    merged.putIfAbsent(entry.key, () => entry.value);
  }

  final userFields = userFieldsOf(current);
  for (final key in userFields) {
    if (old.containsKey(key)) {
      merged[key] = old[key];
    } else {
      merged.remove(key);
    }
  }
  if (userFields.contains('subCategory') && old.containsKey('category')) {
    merged['category'] = old['category'];
  }

  merged.remove(kAiPendingKey);
  if (userFields.isEmpty) {
    merged.remove(kUserFieldsKey);
  } else {
    merged[kUserFieldsKey] = userFields.toList();
  }
  return jsonEncode(merged);
}
