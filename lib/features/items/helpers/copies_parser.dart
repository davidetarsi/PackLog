final _leadingCount = RegExp(r'^\s*(\d{1,2})\s+(\S.*)$');
final _trailingCount = RegExp(r'^(.*\S)\s*,\s*(\d{1,2})\s*$');

/// Cerca le copie scritte nel campo del Rapid Fire: un numero all'inizio
/// ("2 t-shirt nere") o dopo una virgola in fondo ("t-shirt nera, 2").
///
/// Vale solo da 2 a 99: "1 t-shirt" e "0 calzini" restano testo, come
/// "iPhone 15" (il numero non è all'inizio) e "Cavo, 100" (tre cifre). Se ci
/// sono tutti e due i numeri vince quello all'inizio, e il resto è nel nome.
/// Niente "x2" né "n": le copie si scrivono solo col numero.
///
/// Restituisce il nome senza il numero e le copie, o null se non ce ne sono.
({String name, int copies})? parseCopies(String text) {
  final leading = _leadingCount.firstMatch(text);
  if (leading != null) {
    final copies = _inRange(leading.group(1)!);
    if (copies != null) return (name: leading.group(2)!.trim(), copies: copies);
  }
  final trailing = _trailingCount.firstMatch(text);
  if (trailing != null) {
    final copies = _inRange(trailing.group(2)!);
    if (copies != null) {
      return (name: trailing.group(1)!.trim(), copies: copies);
    }
  }
  return null;
}

int? _inRange(String digits) {
  final n = int.parse(digits);
  return n >= 2 && n <= 99 ? n : null;
}
