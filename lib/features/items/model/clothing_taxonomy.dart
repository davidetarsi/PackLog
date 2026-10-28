// Tassonomia dei capi lato app. Specchio di
// supabase/functions/_shared/valigia/tassonomia.ts e di FORMALITA / TAG in
// supabase/functions/_shared/capi/scheda.ts: il test di coerenza
// (test/features/items/model/clothing_taxonomy_test.dart) fallisce se divergono.
//
// I valori salvati restano quelli del server (in inglese); qui non si traduce
// nulla: la traduzione per la vista sta nei dizionari.

/// Categorie in ordine di visualizzazione.
const List<String> kClothingCategories = [
  'Upper Body',
  'Lower Body',
  'Full Body',
  'Shoes',
  'Outerwear',
  'Accessory',
  'Essentials',
];

const String kClothingOther = 'Other';

/// Sottocategorie per categoria: vecchie, poi nuove (ordine di tassonomia.ts),
/// con 'Other' in fondo a ogni gruppo.
const Map<String, List<String>> kClothingTypes = {
  'Upper Body': [
    'T-Shirt',
    'Shirt',
    'Polo',
    'Hoodie',
    'Sweatshirt',
    'Sweater',
    'Tank Top',
    'Crop Top',
    'Thermal Top',
    'Fleece',
    kClothingOther,
  ],
  'Lower Body': [
    'Jeans',
    'Shorts',
    'Trousers',
    'Leggings',
    'Skirt',
    'Sweatpants',
    'Swimwear',
    'Thermal Bottoms',
    'Ski Pants',
    'Wetsuit',
    kClothingOther,
  ],
  'Full Body': ['Dress', kClothingOther],
  'Shoes': [
    'Sneakers',
    'Sandals',
    'Boots',
    'Flip-Flops',
    'Loafers',
    'Dress Shoes',
    'Hiking Boots',
    'Water Shoes',
    'Snow Boots',
    kClothingOther,
  ],
  'Outerwear': [
    'Coat',
    'Rain Jacket',
    'Down Jacket',
    'Windbreaker',
    'Blazer',
    'Ski Jacket',
    'Ski Suit',
    'Casual Jacket',
    'Vest',
    kClothingOther,
  ],
  'Accessory': [
    'Cap/Hat',
    'Belt',
    'Bag',
    'Scarf',
    'Sunglasses',
    'Jewelry',
    'Watch',
    'Gloves',
    'Tie',
    'Umbrella',
    kClothingOther,
  ],
  'Essentials': ['Underwear', 'Socks', 'Pajamas', kClothingOther],
};

/// La categoria di una sottocategoria; null se sconosciuta o se è 'Other'.
String? clothingCategoryOf(String subCategory) {
  if (subCategory == kClothingOther) return null;
  for (final entry in kClothingTypes.entries) {
    if (entry.value.contains(subCategory)) return entry.key;
  }
  return null;
}

const List<int> kWarmthLevels = [1, 2, 3, 4, 5];

const List<int> kWaterResistanceLevels = [0, 1, 2];

const List<String> kFormalities = [
  'Loungewear',
  'Casual',
  'Smart Casual',
  'Business',
  'Formal',
];

const List<String> kActivityTags = [
  'Everyday',
  'Office',
  'Beach',
  'Swimming',
  'Hiking',
  'Sport',
  'Formal',
  'Lounge',
];

/// Colori di base: la tavolozza di COLORI in scheda.ts, i primi sei
/// nell'ordine concordato. Si salva sempre la parola italiana, anche con l'app
/// in inglese.
const List<String> kBaseColors = [
  'Bianco',
  'Nero',
  'Grigio',
  'Blu',
  'Marrone',
  'Beige',
  'Blu navy',
  'Azzurro',
  'Verde',
  'Rosso',
  'Bordeaux',
  'Rosa',
  'Giallo',
  'Arancione',
  'Viola',
  'Multicolore',
];

/// Altri nomi dei colori di base (SINONIMI_COLORE in scheda.ts): i capi
/// salvati prima della tavolozza hanno il colore scritto liberamente.
const Map<String, String> kColorSynonyms = {
  'celeste': 'Azzurro',
  'blu scuro': 'Blu navy',
  'blu notte': 'Blu navy',
  'navy': 'Blu navy',
  'crema': 'Beige',
  'panna': 'Bianco',
  'avorio': 'Bianco',
  'cammello': 'Beige',
  'kaki': 'Beige',
  'cachi': 'Beige',
  'tortora': 'Beige',
  'antracite': 'Grigio',
  'fucsia': 'Rosa',
  'lilla': 'Viola',
  'porpora': 'Viola',
  'bordò': 'Bordeaux',
  'denim': 'Blu',
  'multicolor': 'Multicolore',
  'fantasia': 'Multicolore',
  'white': 'Bianco',
  'black': 'Nero',
  'grey': 'Grigio',
  'gray': 'Grigio',
  'brown': 'Marrone',
  'blue': 'Blu',
  'navy blue': 'Blu navy',
  'light blue': 'Azzurro',
  'green': 'Verde',
  'red': 'Rosso',
  'burgundy': 'Bordeaux',
  'pink': 'Rosa',
  'yellow': 'Giallo',
  'orange': 'Arancione',
  'purple': 'Viola',
  'multicolour': 'Multicolore',
  'multicolored': 'Multicolore',
  'multicoloured': 'Multicolore',
};

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
/// questi.
String? paletteColor(String raw) {
  final testo = raw.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();
  if (testo.isEmpty) return null;
  final nomi = <String, String>{
    for (final colore in kBaseColors) colore.toLowerCase(): colore,
    ...kColorSynonyms,
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

/// Chiave del dizionario per un valore: minuscolo, non alfanumerici → '_'
/// ("Cap/Hat" → "cap_hat").
String clothingKey(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
