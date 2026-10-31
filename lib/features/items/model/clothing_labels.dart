import '../../../core/catalog/catalog_choices.dart';
import '../../../core/catalog/catalog_store.dart';
import 'clothing_taxonomy.dart';

// Etichette da mostrare per i valori salvati. Dal 31 ottobre vengono dal
// catalogo dei tag, nella lingua attiva (CatalogStore.languageCode). Si traduce
// solo la visualizzazione: i valori restano quelli salvati. Un valore che il
// catalogo non conosce torna com'è, senza errori.

String clothingTypeLabel(String subCategory) =>
    etichettaDi('clothing_type', subCategory);

String clothingGroupLabel(String category) =>
    etichettaDi('clothing_group', category);

String warmthLabel(int level) => etichettaDi('warmth', '$level');

String waterResistanceLabel(int level) => etichettaDi('water', '$level');

String formalityLabel(String value) => etichettaDi('formality', value);

String activityLabel(String value) => etichettaDi('use', value);

/// Colore da mostrare: un colore della tavolozza (anche scritto come sinonimo o
/// con una sfumatura, vedi [paletteColor]) si mostra con la sua etichetta del
/// catalogo; gli altri come scritti, con l'iniziale maiuscola. Vuoto o 'N/A' →
/// ''.
String colorLabel(String color) {
  final testo = color.trim();
  if (testo.isEmpty || testo.toUpperCase() == 'N/A') return '';
  final base = paletteColor(testo);
  if (base != null) {
    final voce = CatalogStore.current.find('color', base);
    if (voce != null) return voce.label(CatalogStore.languageCode);
  }
  return '${testo[0].toUpperCase()}${testo.substring(1)}';
}
