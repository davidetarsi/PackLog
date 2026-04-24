import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../items/model/item_model.dart';
import '../../items/repositories/item_repository.dart';

part 'packing_inventory_service.g.dart';

/// Result type for the two-bucket inventory split.
///
/// - [wardrobe]  → clothing items ([ItemCategory.vestiti]) that are
///   weather-compatible with the trip.
/// - [essentials] → non-clothing items (toiletries, electronics, misc) that
///   are always relevant regardless of weather.
typedef InventoryBuckets = ({
  List<ItemModel> wardrobe,
  List<ItemModel> essentials,
});

/// Pre-screens the user's inventory into two packing buckets before the GPT
/// recommendation call, reducing token usage and improving result relevance.
///
/// **Essentials bucket** — items in [ItemCategory.toiletries],
/// [ItemCategory.elettronica], or [ItemCategory.varie]: always included
/// because they are weather-independent by nature.
///
/// **Wardrobe bucket** — items in [ItemCategory.vestiti]: included only if
/// they are weather-compatible with [tripWeatherTags].
/// Items *without* AI metadata (no [ItemModel.aiMetadata]) are always kept
/// since we cannot determine their weather range.
///
/// Weather exclusion uses a mutually-exclusive-extreme rule:
/// - A wardrobe item is **dropped** if its `weather` AI metadata tags are
///   *exclusively* in the opposite thermal extreme from the trip:
///   - Trip is hot ([_hotTags]) → drop items whose weather is ONLY cold ([_coldTags]).
///   - Trip is cold ([_coldTags]) → drop items whose weather is ONLY hot ([_hotTags]).
/// - Items with overlapping tags, empty weather, or "All Season" tags are kept.
class PackingInventoryService {
  final ItemRepository _repository;

  const PackingInventoryService(this._repository);

  // Weather-tag groups used for mutual-exclusivity filtering.
  static const _hotTags = {'Hot', 'Sunny', 'Mild'};
  static const _coldTags = {'Snow', 'Cold'};

  /// Returns a two-bucket split of the user's inventory pre-filtered for
  /// [tripWeatherTags].
  ///
  /// Executes two targeted SQL queries (one per bucket) instead of loading
  /// the whole inventory and filtering everything in Dart.
  Future<InventoryBuckets> getFilteredInventoryForTrip(
    List<String> tripWeatherTags,
  ) async {
    final tripSet = tripWeatherTags.toSet();

    // ── Parallel fetch of both buckets ────────────────────────────────────
    final results = await Future.wait([
      _repository.getAllItemsByCategories([ItemCategory.vestiti]),
      _repository.getAllItemsByCategories([
        ItemCategory.toiletries,
        ItemCategory.elettronica,
        ItemCategory.varie,
      ]),
    ]);

    final clothingItems = results[0];
    final essentialItems = results[1];

    // ── In-memory weather filter for wardrobe ──────────────────────────────
    final wardrobe = clothingItems
        .where((item) => _isWeatherCompatible(item, tripSet))
        .toList();

    return (wardrobe: wardrobe, essentials: essentialItems);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Returns `true` when [item] is compatible with [tripWeatherSet].
  ///
  /// An item is **excluded** only when we have definitive AI evidence that it
  /// belongs to the opposite thermal extreme. When in doubt (no metadata, empty
  /// weather list, or partial overlap) the item is always **kept**.
  bool _isWeatherCompatible(ItemModel item, Set<String> tripWeatherSet) {
    final meta = item.aiMetadata;
    if (meta == null) return true;

    final rawWeather = meta['weather'];
    if (rawWeather is! List || rawWeather.isEmpty) return true;

    final itemWeatherSet = rawWeather.whereType<String>().toSet();
    if (itemWeatherSet.isEmpty) return true;

    final tripIsHot = tripWeatherSet.intersection(_hotTags).isNotEmpty;
    final tripIsCold = tripWeatherSet.intersection(_coldTags).isNotEmpty;

    // Drop cold-only gear on a hot trip.
    if (tripIsHot && !tripIsCold) {
      final itemIsColdOnly = itemWeatherSet.difference(_coldTags).isEmpty;
      if (itemIsColdOnly) return false;
    }

    // Drop hot-only gear on a cold trip.
    if (tripIsCold && !tripIsHot) {
      final itemIsHotOnly = itemWeatherSet.difference(_hotTags).isEmpty;
      if (itemIsHotOnly) return false;
    }

    return true;
  }
}

@riverpod
PackingInventoryService packingInventoryService(Ref ref) {
  return PackingInventoryService(ref.watch(itemRepositoryProvider));
}
