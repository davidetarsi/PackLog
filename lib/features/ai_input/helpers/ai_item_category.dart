import '../../items/model/item_model.dart';

/// Mappa la scheda dell'AI alla categoria dell'app. La categoria decisa da
/// `item-metadata` ([appCategory]: vestiti, varie, toiletries, elettronica)
/// vince; senza, si ricava dalla categoria in inglese della scheda.
ItemCategory aiItemCategory(String category, {String? appCategory}) {
  for (final value in ItemCategory.values) {
    if (value.name == appCategory) return value;
  }
  if (category.toLowerCase().contains('accessory')) {
    return ItemCategory.varie;
  }
  return ItemCategory.vestiti;
}
