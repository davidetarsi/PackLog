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
  });
}
