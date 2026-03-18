import 'template_item_def.dart';
import 'user_gender.dart';
import '../../items/model/item_model.dart';

/// Template di viaggio con item predefiniti.
/// 
/// Rappresenta un tipo di viaggio standard (weekend, business, etc.)
/// con una lista di oggetti comunemente necessari.
class TravelTemplate {
  /// Chiave univoca per identificare il template
  final String key;

  /// Nome visualizzato del template
  final String name;

  /// Nome dell'icona Material da visualizzare
  final String icon;

  /// Descrizione del template
  final String description;

  /// Lista di item predefiniti per questo template
  final List<TemplateItemDef> items;

  const TravelTemplate({
    required this.key,
    required this.name,
    required this.icon,
    required this.description,
    required this.items,
  });

  /// Restituisce gli item filtrati per il genere specificato.
  /// 
  /// Include solo gli item che sono applicabili al genere fornito,
  /// usando la logica definita in [TemplateItemDef.isApplicableForGender].
  List<TemplateItemDef> getItemsByGender(UserGender gender) {
    return items
        .where((item) => item.isApplicableForGender(gender))
        .toList();
  }

  /// Restituisce il conteggio degli item per categoria per il genere specificato.
  /// 
  /// Ritorna una mappa: ItemCategory -> numero di item
  Map<ItemCategory, int> getCategoryCountsByGender(UserGender gender) {
    final filteredItems = getItemsByGender(gender);
    final Map<ItemCategory, int> counts = {};

    for (final item in filteredItems) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    return counts;
  }
}
