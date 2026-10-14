/// Confronto per la ricerca degli oggetti: senza maiuscole né accenti, "il
/// testo contiene la ricerca".
///
/// È volutamente l'unico punto da cambiare quando arriverà il motore che
/// tollera i refusi (fase "Ricerca" dello spec del flusso A): la UI chiama
/// solo [matchesSearch].
library;

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
};

String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

bool matchesSearch(String text, String query) {
  final q = normalizeForSearch(query.trim());
  if (q.isEmpty) return true;
  return normalizeForSearch(text).contains(q);
}
