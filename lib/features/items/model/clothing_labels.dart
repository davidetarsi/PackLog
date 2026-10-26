import 'package:easy_localization/easy_localization.dart';

import 'clothing_taxonomy.dart';

// Etichette da mostrare per i valori salvati (in inglese, come li scrive il
// server). Si traduce solo la visualizzazione: i valori restano quelli salvati.
// Un valore sconosciuto torna com'è, senza errori.

/// Tutte le sottocategorie della tassonomia, 'Other' incluso.
final Set<String> _tuttiITipi = {
  for (final tipi in kClothingTypes.values) ...tipi,
};

String clothingTypeLabel(String subCategory) =>
    _tuttiITipi.contains(subCategory)
    ? 'clothing.type.${clothingKey(subCategory)}'.tr()
    : subCategory;

String clothingGroupLabel(String category) =>
    kClothingCategories.contains(category)
    ? 'clothing.group.${clothingKey(category)}'.tr()
    : category;

String warmthLabel(int level) =>
    kWarmthLevels.contains(level) ? 'clothing.warmth.$level'.tr() : '$level';

String waterResistanceLabel(int level) => kWaterResistanceLevels.contains(level)
    ? 'clothing.water.$level'.tr()
    : '$level';

String formalityLabel(String value) => kFormalities.contains(value)
    ? 'clothing.formality.${clothingKey(value)}'.tr()
    : value;

String activityLabel(String value) => kActivityTags.contains(value)
    ? 'clothing.activity.${clothingKey(value)}'.tr()
    : value;

/// Colore da mostrare: un colore di base si traduce (`clothing.color.<key>`), gli
/// altri si mostrano come scritti, con l'iniziale maiuscola. Vuoto o 'N/A' → ''.
String colorLabel(String color) {
  final testo = color.trim();
  if (testo.isEmpty || testo.toUpperCase() == 'N/A') return '';
  for (final base in kBaseColors) {
    if (base.toLowerCase() == testo.toLowerCase()) {
      return 'clothing.color.${clothingKey(base)}'.tr();
    }
  }
  return '${testo[0].toUpperCase()}${testo.substring(1)}';
}
