import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/analytics/core_analytics_service.dart';
import '../../../../../shared/helpers/snack_bar_helper.dart';
import '../../../../houses/providers/house_provider.dart';
import '../../../../items/providers/item_provider.dart';
import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';
import '../../../providers/trip_provider.dart';
import 'slot_edits.dart';
import 'slot_fill_sheet.dart';

/// Riempire un posto dal dettaglio del viaggio: apre il foglio
/// ([showSlotFillSheet]) e mette in valigia ogni oggetto che vi si scrive.
mixin TripSlotFill on TripSlotEdits {
  /// Apre il foglio per riempire [slot] con uno dei propri oggetti: lo
  /// toccano la riga di un proposto, l'aggiunta sulla card di un importante e
  /// "Presa" su un "da comprare". Se la casa di partenza non c'è più il foglio
  /// non si apre e uno snack lo dice.
  void openSlot(AiSlot slot) {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final id = tripId;
    final houseId = ref
        .read(tripNotifierProvider)
        .valueOrNull
        ?.where((t) => t.id == tripId)
        .firstOrNull
        ?.aiResult
        ?.houseId;
    final houses = ref.read(houseNotifierProvider).valueOrNull;
    if (houseId == null ||
        houses == null ||
        !houses.any((h) => h.id == houseId)) {
      AppSnackBar.showInfo(context, 'trips.slots.no_house'.tr());
      return;
    }
    final wasToBuy = slot.toBuy;
    unawaited(
      showSlotFillSheet(
        context,
        slot: slot,
        houseId: houseId,
        tripId: tripId,
        onFill: (item) async {
          await _fillSlot(
            container,
            messenger,
            id,
            slot,
            item,
            linkInventory: false,
            bought: wasToBuy,
          );
        },
        onLinkInventory: (item) => _fillSlot(
          container,
          messenger,
          id,
          slot,
          item,
          linkInventory: true,
          bought: wasToBuy,
        ),
        onToBuy: () => unawaited(markSlotToBuy(slot, from: 'sheet')),
      ),
    );
  }

  /// L'oggetto appena creato entra in valigia e scala il posto. Se il
  /// salvataggio non va lo dice e rilancia (l'oggetto resta nella casa).
  Future<int> _fillSlot(
    ProviderContainer container,
    ScaffoldMessengerState messenger,
    String id,
    AiSlot slot,
    TripItem item, {
    required bool linkInventory,
    required bool bought,
  }) async {
    final notifier = container.read(tripNotifierProvider.notifier);
    final analytics = container.read(coreAnalyticsServiceProvider);
    try {
      var applied = 0;
      await notifier.serializeEdit(id, () async {
        final trips = await container.read(tripNotifierProvider.future);
        final trip = trips.where((candidate) => candidate.id == id).firstOrNull;
        if (trip == null) throw StateError('trip no longer available');

        final currentSlot = trip.aiResult?.slots
            ?.where((candidate) => candidate.id == slot.id)
            .firstOrNull;
        if (currentSlot == null || currentSlot.removed) {
          throw StateError('slot no longer available');
        }
        if (linkInventory && !currentSlot.isOpen) {
          throw StateError('slot is already complete');
        }

        final houseId = trip.aiResult?.houseId;
        if (houseId == null || item.originHouseId != houseId) {
          throw StateError('inventory source changed');
        }
        final inventory = await container.read(
          itemNotifierProvider(houseId).future,
        );
        final source = inventory
            .where((candidate) => candidate.id == item.id)
            .firstOrNull;
        if (source == null || source.houseId != houseId) {
          throw StateError('inventory source no longer available');
        }

        final alreadyPacked = trip.items
            .where((packed) => packed.id == source.id)
            .fold<int>(0, (total, packed) => total + packed.quantity);
        final available = math.max(0, (source.quantity ?? 1) - alreadyPacked);
        if (item.quantity <= 0) throw StateError('invalid quantity');
        if (!linkInventory && item.quantity > available) {
          throw StateError('created inventory quantity changed');
        }
        final quantity = linkInventory
            ? math.min(
                item.quantity,
                math.min(available, currentSlot.remaining),
              )
            : item.quantity;
        if (quantity == 0) throw StateError('inventory quantity changed');

        await notifier.fillAiSlot(
          id,
          slot.id,
          TripItem(
            id: source.id,
            name: source.name,
            category: source.category,
            quantity: quantity,
            originHouseId: source.houseId,
          ),
        );
        final savedTrip = container
            .read(tripNotifierProvider)
            .valueOrNull
            ?.where((candidate) => candidate.id == id)
            .firstOrNull;
        if (savedTrip == null ||
            !savedTrip.items.any((packed) => packed.id == source.id)) {
          throw StateError('fill was not saved');
        }
        applied = quantity;
      });
      // Un posto "da comprare" si apre solo con "Presa": riempirlo vuol dire
      // che l'hai comprato.
      if (bought) {
        analytics.trackSlotBought(level: slot.level.name);
      }
      return applied;
    } catch (_) {
      if (messenger.mounted) {
        AppSnackBar.showErrorOn(messenger, 'errors.save_error'.tr());
      }
      rethrow;
    }
  }
}
