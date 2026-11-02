import '../../../core/catalog/catalog.dart';
import '../../../shared/helpers/search_match.dart';

/// Le attività e i mezzi che il nome di un kit fa pensare.
class KitUses {
  const KitUses({this.activities = const [], this.transports = const []});

  final List<String> activities;
  final List<String> transports;

  bool get isEmpty => activities.isEmpty && transports.isEmpty;
}

/// Riconosce dal nome del kit le attività e i mezzi del catalogo.
///
/// Confronto senza maiuscole e accenti fra le parole del nome e `label_it`,
/// `label_en`, `id` e `data.alias` delle voci attive di `activity` e
/// `transport`. Una parola vale se è uguale a un alias o inizia con un alias
/// di almeno 4 lettere; un alias di più parole ("settimana bianca") vale se
/// compare nel nome come parole intere.
KitUses usesFromName(String name, Catalog catalog) {
  final words = _words(name);
  if (words.isEmpty) return const KitUses();
  final padded = ' ${words.join(' ')} ';

  List<String> match(String domain) => [
    for (final entry in catalog.domain(domain))
      if (_aliases(entry).any((a) => _matches(a, words, padded))) entry.id,
  ];

  return KitUses(activities: match('activity'), transports: match('transport'));
}

List<String> _words(String text) => normalizeForSearch(
  text,
).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();

Set<String> _aliases(CatalogEntry entry) {
  final alias = entry.data['alias'];
  return {
    for (final raw in [
      entry.id.replaceAll('_', ' '),
      entry.labelIt,
      entry.labelEn,
      if (alias is List) ...alias.map((a) => a.toString()),
    ])
      if (_words(raw).isNotEmpty) _words(raw).join(' '),
  };
}

bool _matches(String alias, List<String> words, String padded) {
  if (alias.contains(' ')) return padded.contains(' $alias ');
  return words.any(
    (w) => w == alias || (alias.length >= 4 && w.startsWith(alias)),
  );
}
