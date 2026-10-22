import '../model/model.dart';

/// Riordina i suggerimenti come ci si aspetta da una ricerca di luoghi: prima
/// quello che si chiama esattamente come il testo scritto, poi quelli che
/// iniziano così, poi gli altri. A parità, le città prima delle regioni e
/// delle nazioni; a parità ancora, l'ordine di Geoapify (che tiene conto
/// dell'importanza del posto).
///
/// Così "Milano" dà Milano per prima, "Italia" dà l'Italia, e "Ve" dà
/// Venezia e Verona prima del Veneto.
List<LocationSuggestionModel> rankLocationSuggestions(
  String query,
  List<LocationSuggestionModel> suggestions,
) {
  final q = normalizePlaceName(query);
  if (q.isEmpty) return suggestions;

  int matchScore(LocationSuggestionModel s) {
    final name = normalizePlaceName(s.name ?? s.displayName);
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    if (name.split(RegExp(r'[\s\-]')).any((w) => w.startsWith(q))) return 2;
    return 3;
  }

  int typeScore(LocationType type) => switch (type) {
    LocationType.city => 0,
    LocationType.state => 1,
    LocationType.country => 2,
    LocationType.other => 3,
  };

  final indexed = suggestions.indexed.toList();
  indexed.sort((a, b) {
    final byMatch = matchScore(a.$2).compareTo(matchScore(b.$2));
    if (byMatch != 0) return byMatch;
    final byType = typeScore(
      a.$2.locationType,
    ).compareTo(typeScore(b.$2.locationType));
    if (byType != 0) return byType;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, s) in indexed) s];
}

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n', 'ß': 'ss',
};

/// Minuscolo, senza accenti e spazi in eccesso: "  Forlì " → "forli".
String normalizePlaceName(String value) {
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}
