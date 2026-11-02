import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/catalog/catalog_choices.dart';
import '../../../../../core/catalog/catalog_provider.dart';
import '../../../../../shared/helpers/snack_bar_helper.dart';
import '../../../../items/providers/item_provider.dart';
import '../../../../kits/providers/kit_provider.dart';
import '../../../helpers/kit_row_state.dart';
import '../../../model/trip_model.dart';
import '../../../providers/trip_provider.dart';
import 'kit_learn_row.dart';
import 'kit_suggestion_row.dart';
import 'slot_actions.dart';

/// La riga del kit in valigia: una alla volta, fra la barra e i gruppi.
/// Prima la domanda sul kit ([KitSuggestionRow]); dopo un "Aggiungili", se un
/// uso del viaggio ha già abbastanza sì, la domanda se impararlo
/// ([KitLearnRow]). Non c'è nulla da mostrare finché non servono.
class TripKitRow extends ConsumerStatefulWidget {
  const TripKitRow({super.key, required this.trip, required this.flyKitItems});

  final TripModel trip;
  final FlyKitItems flyKitItems;

  @override
  ConsumerState<TripKitRow> createState() => _TripKitRowState();
}

class _TripKitRowState extends ConsumerState<TripKitRow> {
  final _rowKey = GlobalKey();

  /// Il collegamento da proporre di imparare, dopo un "Aggiungili".
  ({String kitId, String use})? _learn;

  String? get _houseId => widget.trip.aiResult?.houseId;

  Future<void> _add(KitRowState row) async {
    final trip = widget.trip;
    final notifier = ref.read(tripNotifierProvider.notifier);
    final kits = ref.read(kitNotifierProvider(_houseId!).notifier);
    final counted = !trip.aiResult!.kitLearnCounted.contains(row.kit.id);
    final box = _rowKey.currentContext?.findRenderObject();
    final from = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    final updated = applyKitAdded(trip, row, counted: counted);
    final landing = [
      for (final item in updated.items)
        if (row.plan.toAdd.any((a) => a.id == item.id) ||
            row.plan.raised.containsKey(item.id))
          item,
    ];
    try {
      await widget.flyKitItems(
        from: from,
        items: landing,
        save: () => notifier.updateTrip(updated),
      );
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      return;
    }
    // Il sì si conta una volta sola per kit e viaggio, anche se la valigia si
    // rigenera.
    var kit = row.kit;
    if (counted) {
      try {
        kit = await kits.recordYes(row.kit.id, tripUses(trip));
      } catch (_) {
        // L'oggetto è già in valigia: il conteggio non è essenziale.
      }
    }
    final use = learnCandidate(kit, tripUses(trip));
    if (mounted && use != null) {
      setState(() => _learn = (kitId: kit.id, use: use));
    }
  }

  Future<void> _dismiss(KitRowState row) async {
    try {
      await ref
          .read(tripNotifierProvider.notifier)
          .updateTrip(applyKitDismissed(widget.trip, row.kit.id));
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }

  Future<void> _answerLearn(bool yes) async {
    final learn = _learn;
    if (learn == null) return;
    setState(() => _learn = null);
    final kits = ref.read(kitNotifierProvider(_houseId!).notifier);
    try {
      if (yes) {
        await kits.learnUse(learn.kitId, learn.use);
      } else {
        await kits.refuseUse(learn.kitId, learn.use);
      }
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseId = _houseId;
    // Senza kit da proporre (la maggior parte dei viaggi) non si legge niente.
    if (houseId == null ||
        (widget.trip.aiResult!.kitSuggestions.isEmpty && _learn == null)) {
      return const SizedBox.shrink();
    }
    ref.watch(catalogRevisionProvider);
    final kits = ref.watch(kitNotifierProvider(houseId)).valueOrNull;
    final houseItems = ref.watch(itemNotifierProvider(houseId)).valueOrNull;
    if (kits == null || houseItems == null) return const SizedBox.shrink();

    final row = pickKitRow(
      trip: widget.trip,
      kits: kits,
      houseItems: houseItems,
    );
    final learn = _learn;
    if (learn != null) {
      return KitLearnRow(
        useLabel: etichettaDi(useDomain(learn.use), learn.use),
        onYes: () => unawaited(_answerLearn(true)),
        onNo: () => unawaited(_answerLearn(false)),
      );
    }
    if (row != null) {
      return KitSuggestionRow(
        key: _rowKey,
        kitName: row.kit.name,
        taken: row.taken,
        total: row.total,
        missing: row.missing,
        onAdd: () => unawaited(_add(row)),
        onDismiss: () => unawaited(_dismiss(row)),
      );
    }
    return const SizedBox.shrink();
  }
}
