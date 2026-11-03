import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/analytics/analytics_service.dart';
import '../../../../../shared/helpers/design_system.dart';
import '../../../../../shared/helpers/snack_bar_helper.dart';
import '../../../model/ai_packing.dart';
import '../../../providers/trip_provider.dart';
import '../../trip_detail_screen.dart';

/// Le modifiche ai posti dal dettaglio del viaggio: "Da comprare", togliere,
/// la casella di un proposto. Ognuna salva subito e, se non va, lo dice.
mixin TripSlotEdits on ConsumerState<TripDetailScreen> {
  String get tripId => widget.tripId;

  /// "Da comprare" sulla card di un importante: la card diventa una riga
  /// "da comprare"; Annulla la riporta.
  Future<void> markSlotToBuy(AiSlot slot, {String from = 'card'}) async {
    // Il notifier si legge ora: Annulla può arrivare quando la pagina non c'è
    // più, e allora `ref` non si può usare.
    final notifier = ref.read(tripNotifierProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    final saved = await updateSlot(
      notifier,
      slot,
      (s) => s.copyWith(toBuy: true),
    );
    if (!saved) return;
    unawaited(
      analytics.logEvent(
        'slot_marked_to_buy',
        properties: {'level': slot.level.name, 'from': from},
      ),
    );
    if (!mounted) return;
    AppSnackBar.showUndo(
      context,
      'trips.slots.marked_to_buy'.tr(),
      onUndo: () => unawaited(
        updateSlot(notifier, slot, (s) => s.copyWith(toBuy: false)),
      ),
    );
  }

  /// Toglie [slot] dalla valigia (`removed`). Con [confirm] chiede prima,
  /// con il motivo del posto (la X di un importante); senza toglie subito e
  /// Annulla lo rimette (lo scorrimento di una proposta).
  Future<void> removeSlot(AiSlot slot, {required bool confirm}) async {
    // Il notifier si legge ora: Annulla può arrivare quando la pagina non c'è
    // più, e allora `ref` non si può usare.
    final notifier = ref.read(tripNotifierProvider.notifier);
    if (confirm) {
      final reason = slot.reason;
      final ok = await DialogHelpers.showConfirmation(
        context: context,
        title: 'trips.slots.remove_title'.tr(args: [slot.name]),
        message: [
          'trips.slots.remove_body'.tr(),
          if (reason != null && reason.isNotEmpty) reason,
        ].join(' '),
        confirmLabel: 'trips.slots.remove_confirm'.tr(),
      );
      if (!ok) return;
    }
    final saved = await updateSlot(
      notifier,
      slot,
      (s) => s.copyWith(removed: true),
    );
    if (!saved || confirm || !mounted) return;
    AppSnackBar.showUndo(
      context,
      'trips.slots.removed'.tr(args: [slot.name]),
      onUndo: () => unawaited(
        updateSlot(notifier, slot, (s) => s.copyWith(removed: false)),
      ),
    );
  }

  /// La casella di un proposto, quando non si sta più sistemando.
  void toggleSlot(AiSlot slot) {
    unawaited(
      updateSlot(
        ref.read(tripNotifierProvider.notifier),
        slot,
        (s) => s.copyWith(checked: !s.checked),
      ),
    );
  }

  /// Cambia il posto e salva; se il salvataggio non va lo dice (se la pagina
  /// c'è ancora) e torna `false` (il posto è già tornato com'era).
  Future<bool> updateSlot(
    TripNotifier notifier,
    AiSlot slot,
    AiSlot Function(AiSlot) change,
  ) async {
    try {
      await notifier.updateAiSlot(tripId, slot.id, change);
      return true;
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      return false;
    }
  }
}
