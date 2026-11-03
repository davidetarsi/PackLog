import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/analytics/analytics_service.dart';
import '../../../../../shared/helpers/snack_bar_helper.dart';
import '../../../../houses/providers/house_provider.dart';
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
    // "Presa" su una proposta da comprare: torna nella valigia, in cima ai
    // proposti.
    if (slot.toBuy && slot.level == AiSlotLevel.useful) {
      unawaited(
        updateSlot(
          ref.read(tripNotifierProvider.notifier),
          slot,
          (s) => s.copyWith(toBuy: false),
        ),
      );
    }
    unawaited(
      showSlotFillSheet(
        context,
        slot: slot,
        houseId: houseId,
        onFill: (item) => _fillSlot(slot, item),
        onToBuy: () => unawaited(markSlotToBuy(slot, from: 'sheet')),
      ),
    );
  }

  /// L'oggetto appena creato entra in valigia e scala il posto. Se il
  /// salvataggio non va lo dice (l'oggetto resta nella casa).
  Future<void> _fillSlot(AiSlot slot, TripItem item) async {
    final notifier = ref.read(tripNotifierProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    try {
      await notifier.fillAiSlot(tripId, slot.id, item);
      // Un posto "da comprare" si apre solo con "Presa": riempirlo vuol dire
      // che l'hai comprato.
      if (slot.toBuy) {
        unawaited(
          analytics.logEvent(
            'slot_bought',
            properties: {'level': slot.level.name},
          ),
        );
      }
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }
}
