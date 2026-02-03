import '../../../features/items/model/item_model.dart';

/// Funzioni helper per convertire ItemCategory da/verso String.
/// 
/// Drift salva le categorie come stringhe nel database.
class ItemCategoryConverter {
  /// Converte ItemCategory in String per il database
  static String toDatabase(ItemCategory category) {
    return category.name;
  }

  /// Converte String dal database in ItemCategory
  static ItemCategory fromDatabase(String value) {
    return ItemCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemCategory.varie,
    );
  }
}
