import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';

/// Da chiamare in `setUpAll` dei test che usano un [ItemRepository] finto.
void registerAiMetadataFallback() {
  AiMetadataChange? nothing(ItemModel current) => null;
  registerFallbackValue(nothing);
}

/// Fa scrivere a `updateAiMetadata` del repository finto [repo] come quello
/// vero: legge la riga con `getItemById` (se lancia, l'oggetto non c'è più),
/// chiede a `compute` cosa scrivere e scrive con `updateItem`.
void stubAiMetadataWrite(ItemRepository repo) {
  when(
    () =>
        repo.updateAiMetadata(any(), any(), updatedAt: any(named: 'updatedAt')),
  ).thenAnswer((i) async {
    final id = i.positionalArguments[0] as String;
    final compute =
        i.positionalArguments[1] as AiMetadataChange? Function(ItemModel);
    final ItemModel current;
    try {
      current = await repo.getItemById(id);
    } catch (_) {
      return null;
    }
    final change = compute(current);
    if (change == null) return null;
    final written = current.copyWith(
      aiMetadata: change.aiMetadata,
      category: change.category ?? current.category,
      updatedAt: (i.namedArguments[#updatedAt] as DateTime?) ?? DateTime.now(),
    );
    await repo.updateItem(written);
    return written;
  });
}
