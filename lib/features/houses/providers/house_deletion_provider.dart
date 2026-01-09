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
    return HouseDeletionBlocker(
      canDelete: false,
      reason: 'La casa contiene $itemsCount oggett${itemsCount == 1 ? 'o' : 'i'}. '
              'Rimuovi tutti gli oggetti prima di eliminare la casa.',
      itemsCount: itemsCount,
      tripsAsOriginCount: tripsAsOriginCount,
      tripsAsDestinationCount: tripsAsDestinationCount,
    );
  }

  if (tripsAsOriginCount > 0 || tripsAsDestinationCount > 0) {
    final reasons = <String>[];
    if (tripsAsOriginCount > 0) {
      reasons.add('$tripsAsOriginCount viagg${tripsAsOriginCount == 1 ? 'io attivo/programmato contiene' : 'i attivi/programmati contengono'} oggetti provenienti da questa casa');
    }
    if (tripsAsDestinationCount > 0) {
      reasons.add('$tripsAsDestinationCount viagg${tripsAsDestinationCount == 1 ? 'io attivo/programmato ha' : 'i attivi/programmati hanno'} questa casa come destinazione');
    }

    return HouseDeletionBlocker(
      canDelete: false,
      reason: '${reasons.join('. ')}. Attendi la fine dei viaggi o eliminali prima di eliminare la casa.',
      itemsCount: itemsCount,
      tripsAsOriginCount: tripsAsOriginCount,
      tripsAsDestinationCount: tripsAsDestinationCount,
    );
  }

  return HouseDeletionBlocker.allowed;
}

