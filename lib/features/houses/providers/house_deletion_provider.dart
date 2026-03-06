import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../items/providers/item_provider.dart';
import '../../trips/providers/trip_provider.dart';

part 'house_deletion_provider.g.dart';

/// Motivo per cui una casa non può essere eliminata
class HouseDeletionBlocker {
  final bool canDelete;
  final String? reason;
  final int itemsCount;
  final int tripsAsOriginCount;
  final int tripsAsDestinationCount;

  const HouseDeletionBlocker({
    required this.canDelete,
    this.reason,
    this.itemsCount = 0,
    this.tripsAsOriginCount = 0,
    this.tripsAsDestinationCount = 0,
  });

  static const HouseDeletionBlocker allowed = HouseDeletionBlocker(canDelete: true);
}

/// Provider che verifica se una casa può essere eliminata
@riverpod
Future<HouseDeletionBlocker> canDeleteHouse(Ref ref, String houseId) async {
  // Controlla se ci sono items nella casa
  final itemsAsync = ref.watch(itemNotifierProvider(houseId));
  final items = itemsAsync.value ?? [];
  final itemsCount = items.length;

  // Controlla se ci sono viaggi che coinvolgono questa casa
  final tripsAsync = ref.watch(tripNotifierProvider);
  final trips = tripsAsync.value ?? [];

  int tripsAsOriginCount = 0;
  int tripsAsDestinationCount = 0;

  for (final trip in trips) {
    // Ignora i viaggi già completati - non bloccano l'eliminazione
    if (trip.isCompleted) continue;

    // Controlla se la casa è la destinazione di un viaggio attivo o futuro
    if (trip.destinationHouseId == houseId) {
      tripsAsDestinationCount++;
    }

    // Controlla se ci sono items che provengono da questa casa in viaggi attivi o futuri
    final hasItemsFromHouse = trip.items.any((item) => item.originHouseId == houseId);
    if (hasItemsFromHouse) {
      tripsAsOriginCount++;
    }
  }

  // Determina se può essere eliminata
  if (itemsCount > 0) {
    final itemWord = itemsCount == 1 
        ? 'houses.item_singular'.tr() 
        : 'houses.item_plural'.tr();
    return HouseDeletionBlocker(
      canDelete: false,
      reason: 'houses.cannot_delete_has_items_count'.tr(args: [itemsCount.toString(), itemWord]),
      itemsCount: itemsCount,
      tripsAsOriginCount: tripsAsOriginCount,
      tripsAsDestinationCount: tripsAsDestinationCount,
    );
  }

  if (tripsAsOriginCount > 0 || tripsAsDestinationCount > 0) {
    final reasons = <String>[];
    if (tripsAsOriginCount > 0) {
      final tripMessage = tripsAsOriginCount == 1
          ? 'houses.trips_contain_items_singular'.tr(args: [tripsAsOriginCount.toString()])
          : 'houses.trips_contain_items_plural'.tr(args: [tripsAsOriginCount.toString()]);
      reasons.add(tripMessage);
    }
    if (tripsAsDestinationCount > 0) {
      final tripMessage = tripsAsDestinationCount == 1
          ? 'houses.trips_has_destination_singular'.tr(args: [tripsAsDestinationCount.toString()])
          : 'houses.trips_has_destination_plural'.tr(args: [tripsAsDestinationCount.toString()]);
      reasons.add(tripMessage);
    }

    return HouseDeletionBlocker(
      canDelete: false,
      reason: '${reasons.join('. ')}. ${'houses.wait_trips_end'.tr()}',
      itemsCount: itemsCount,
      tripsAsOriginCount: tripsAsOriginCount,
      tripsAsDestinationCount: tripsAsDestinationCount,
    );
  }

  return HouseDeletionBlocker.allowed;
}

