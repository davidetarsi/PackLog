import 'clothing_details.dart';
import 'clothing_taxonomy.dart';

/// Colori di base usati da qualche capo, letti dai metadati degli oggetti.
///
/// Ignora vuoti e 'N/A'; i doppioni ignorano maiuscole e spazi. Per ogni
/// colore si mostra la grafia più frequente (a parità, la prima incontrata).
/// Ordine: frequenza decrescente, poi alfabetico senza maiuscole.
List<String> usedColorsFrom(Iterable<String?> aiMetadata) {
  final counts = <String, int>{};
  final spellings = <String, Map<String, int>>{};

  for (final raw in aiMetadata) {
    final color = clothingFromMetadata(raw)?.baseColor.trim() ?? '';
    if (color.isEmpty || color.toLowerCase() == 'n/a') continue;
    final key = color.toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    final forms = spellings.putIfAbsent(key, () => <String, int>{});
    forms[color] = (forms[color] ?? 0) + 1;
  }

  String displayOf(String key) {
    String best = '';
    var bestCount = 0;
    spellings[key]!.forEach((form, count) {
      if (count > bestCount) {
        best = form;
        bestCount = count;
      }
    });
    return best;
  }

  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final key in keys) displayOf(key)];
}

/// Lo stesso colore per le pillole: quello della tavolozza se lo è ("Verde
/// oliva" e "verde" sono la pillola Verde), se no il testo senza maiuscole né
/// spazi ai bordi.
String colorIdentity(String color) =>
    (paletteColor(color) ?? color.trim()).toLowerCase();

/// Pillole del colore: i colori di base, seguiti dai colori dell'utente che
/// non sono già tra quelli di base (vedi [colorIdentity]).
List<String> colorChoices(List<String> userColors) {
  final seen = {for (final c in kBaseColors) colorIdentity(c)};
  return [
    ...kBaseColors,
    for (final color in userColors)
      if (seen.add(colorIdentity(color))) color.trim(),
  ];
}
