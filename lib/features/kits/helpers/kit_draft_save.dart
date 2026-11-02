import '../model/kit_model.dart';
import '../providers/kit_provider.dart';

/// Salva la bozza dell'editor: un kit nuovo con i suoi oggetti, oppure le
/// differenze su un kit esistente (nome, pillole, oggetti tolti, aggiunti o
/// con le copie cambiate). Lancia `KitLimitException` oltre i limiti.
Future<void> saveKitDraft(
  KitNotifier notifier, {
  required KitModel? existing,
  required String name,
  required List<String> activities,
  required List<String> transports,
  required Map<String, int> items,
}) async {
  if (existing == null) {
    final kit = await notifier.createKit(
      name: name,
      activities: activities,
      transports: transports,
    );
    if (items.isNotEmpty) await notifier.addItems(kit.id, items);
    return;
  }
  await notifier.updateKit(
    existing.copyWith(
      name: name,
      activities: activities,
      transports: transports,
    ),
  );
  final kept = {for (final i in existing.items) i.itemId: i.copies};
  for (final id in kept.keys.where((id) => !items.containsKey(id))) {
    await notifier.removeItem(existing.id, id);
  }
  final changed = {
    for (final e in items.entries)
      if (kept[e.key] != e.value) e.key: e.value,
  };
  if (changed.isNotEmpty) await notifier.addItems(existing.id, changed);
}
