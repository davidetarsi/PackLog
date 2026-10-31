// Tassonomia dei capi lato app. Dal 31 ottobre 2026 gruppi, tipi, stile, usi e
// colori vengono dal catalogo dei tag (core/catalog, letto da CatalogStore), non
// da liste scritte qui: una voce nuova o disattivata si cambia sul server senza
// store. Restano nel codice le scale numeriche (calore, impermeabilità) e le
// regole di lettura dei colori.
//
// I valori salvati sono quelli del server (in inglese per i tipi): qui non si
// traduce nulla. La traduzione per la vista sta in clothing_labels.dart.

import '../../../core/catalog/catalog_store.dart';

/// Il tipo "altro", in ogni gruppo.
const String kClothingOther = 'Other';

const List<int> kWarmthLevels = [1, 2, 3, 4, 5];

const List<int> kWaterResistanceLevels = [0, 1, 2];

/// Le categorie (gruppi dei tipi) in ordine di visualizzazione.
List<String> clothingCategories() => [
  for (final voce in CatalogStore.current.domain('clothing_group')) voce.id,
];

/// Le sottocategorie per categoria, nell'ordine del catalogo, con 'Other' in
/// fondo a ogni gruppo. [activeOnly] false include anche le disattivate, che
/// servono a leggere i capi salvati prima.
Map<String, List<String>> clothingTypes({bool activeOnly = true}) {
  final tipi = CatalogStore.current.domain(
    'clothing_type',
    activeOnly: activeOnly,
  );
  return {
    for (final categoria in clothingCategories())
      categoria: [
        for (final voce in tipi)
          if (voce.id != kClothingOther && voce.data['group'] == categoria)
            voce.id,
        kClothingOther,
      ],
  };
}

/// La categoria di una sottocategoria, anche disattivata; null se sconosciuta
/// o se è 'Other'.
String? clothingCategoryOf(String subCategory) {
  if (subCategory == kClothingOther) return null;
  final gruppo = CatalogStore.current
      .find('clothing_type', subCategory)
      ?.data['group'];
  return gruppo is String ? gruppo : null;
}

/// Gli usi (tag di attività), nell'ordine del catalogo.
List<String> activityTags({bool activeOnly = true}) => [
  for (final voce in CatalogStore.current.domain('use', activeOnly: activeOnly))
    voce.id,
];

/// Gli stili (formalità), nell'ordine del catalogo.
List<String> formalities({bool activeOnly = true}) => [
  for (final voce in CatalogStore.current.domain(
    'formality',
    activeOnly: activeOnly,
  ))
    voce.id,
];

/// I colori di base (la tavolozza), nell'ordine del catalogo.
List<String> baseColors({bool activeOnly = true}) => [
  for (final voce in CatalogStore.current.domain(
    'color',
    activeOnly: activeOnly,
  ))
    voce.id,
];

/// Altri nomi dei colori di base (minuscoli): da `data.synonyms` del catalogo.
Map<String, String> colorSynonyms() => {
  for (final voce in CatalogStore.current.domain('color', activeOnly: false))
    for (final sinonimo
        in (voce.data['synonyms'] as List<dynamic>? ?? const []))
      (sinonimo as String): voce.id,
};

/// Ordina gli usi di un capo: prima quelli del catalogo (nel suo ordine,
/// anche se disattivati), poi quelli che il catalogo non conosce, nell'ordine
/// in cui erano. Non si perde nessun uso.
List<String> ordinaUsi(Iterable<String> usi) {
  final scelti = <String>{...usi};
  final conosciuti = [
    for (final id in activityTags(activeOnly: false))
      if (scelti.contains(id)) id,
  ];
  return [
    ...conosciuti,
    for (final uso in scelti)
      if (!conosciuti.contains(uso)) uso,
  ];
}

/// Sfumature che non cambiano il colore di base: "Verde oliva" è verde,
/// "Grigio chiaro" è grigio. "Verde salvia" no: resta com'è scritto.
const Set<String> _sfumature = {
  'scuro',
  'scura',
  'chiaro',
  'chiara',
  'oliva',
  'militare',
  'notte',
  'pastello',
  'acceso',
  'accesa',
  'melange',
  'mélange',
};

/// Le sfumature inglesi vengono prima del colore: "dark blue".
const Set<String> _sfumatureInglesi = {'dark', 'light'};

/// Il colore della tavolozza per un colore scritto: uguale senza maiuscole,
/// un sinonimo, o un colore di base con una sfumatura. Null se non è uno di
/// questi. Usa anche le voci disattivate: un capo salvato le conserva.
String? paletteColor(String raw) {
  final testo = raw.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();
  if (testo.isEmpty) return null;
  final nomi = <String, String>{
    for (final colore in baseColors(activeOnly: false))
      colore.toLowerCase(): colore,
    ...colorSynonyms(),
  };
  final esatto = nomi[testo];
  if (esatto != null) return esatto;
  final ultimo = testo.lastIndexOf(' ');
  if (ultimo > 0 && _sfumature.contains(testo.substring(ultimo + 1))) {
    return nomi[testo.substring(0, ultimo)];
  }
  final primo = testo.indexOf(' ');
  if (primo > 0 && _sfumatureInglesi.contains(testo.substring(0, primo))) {
    return nomi[testo.substring(primo + 1)];
  }
  return null;
}
