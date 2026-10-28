import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/helpers/ai_item_category.dart';
import 'package:pack_log/features/items/model/item_model.dart';

void main() {
  group('aiItemCategory', () {
    test('maps clothing categories used by the AI prompt to vestiti', () {
      for (final category in [
        'Upper Body',
        'Lower Body',
        'Shoes',
        'Outerwear',
      ]) {
        expect(
          aiItemCategory(category),
          ItemCategory.vestiti,
          reason: category,
        );
      }
    });

    test('maps Accessory to varie case-insensitively', () {
      expect(aiItemCategory('Accessory'), ItemCategory.varie);
      expect(aiItemCategory('accessory'), ItemCategory.varie);
    });

    test('keeps legacy fallback to vestiti for unknown categories', () {
      expect(aiItemCategory('Unknown AI category'), ItemCategory.vestiti);
    });

    test('the app category from item-metadata wins over the AI category', () {
      expect(
        aiItemCategory('Not Clothing', appCategory: 'toiletries'),
        ItemCategory.toiletries,
      );
      expect(
        aiItemCategory('Upper Body', appCategory: 'elettronica'),
        ItemCategory.elettronica,
      );
      // Un valore sconosciuto torna alla regola sulla categoria inglese.
      expect(
        aiItemCategory('Accessory', appCategory: 'boh'),
        ItemCategory.varie,
      );
    });
  });

  group('appCategoryKey', () {
    test('usa le chiavi che manda item-metadata', () {
      expect(
        {for (final c in ItemCategory.values) appCategoryKey(c)},
        {'vestiti', 'toiletries', 'elettronica', 'varie'},
      );
    });

    test('torna la categoria letta dal server', () {
      for (final category in ItemCategory.values) {
        expect(
          aiItemCategory('Upper Body', appCategory: appCategoryKey(category)),
          category,
        );
      }
    });
  });
}
