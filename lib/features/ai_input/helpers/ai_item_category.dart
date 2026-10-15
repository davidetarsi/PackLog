import '../../items/model/item_model.dart';

/// Mappa le categorie in inglese prodotte dall'AI alle categorie dell'app.
ItemCategory aiItemCategory(String category) {
  if (category.toLowerCase().contains('accessory')) {
    return ItemCategory.varie;
  }
  return ItemCategory.vestiti;
}
