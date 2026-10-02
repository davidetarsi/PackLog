import 'package:drift/drift.dart';
import '../../../features/items/model/item_model.dart';

/// Converter Drift nativo per serializzare [ItemCategory] ↔ [String].
///
/// Viene applicato direttamente alla definizione della colonna nelle tabelle
/// Drift (`.map(const ItemCategoryConverter())`), così il codice generato
/// espone già il tipo `ItemCategory` invece di `String` e la conversione
/// avviene in un solo posto senza duplicazioni nei repository.
class ItemCategoryConverter extends TypeConverter<ItemCategory, String> {
  const ItemCategoryConverter();

  @override
  ItemCategory fromSql(String fromDb) {
    return ItemCategory.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => ItemCategory.varie,
    );
  }

  @override
  String toSql(ItemCategory value) => value.name;

  // ── Backward-compat helpers (usati da MigrationService e unit test) ──────
  // Delegano all'istanza per restare allineati alla logica del TypeConverter.

  /// Converte [ItemCategory] in String per il database.
  static String toDatabase(ItemCategory category) =>
      const ItemCategoryConverter().toSql(category);

  /// Converte String dal database in [ItemCategory].
  static ItemCategory fromDatabase(String value) =>
      const ItemCategoryConverter().fromSql(value);
}
