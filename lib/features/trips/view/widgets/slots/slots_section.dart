import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_group_header.dart';
import '../../../../items/model/item_model.dart';
import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';
import 'slot_actions.dart';
import 'slot_widgets.dart';
import 'trip_kit_row.dart';
import 'trip_items_card.dart' show EmptySuitcase;

/// Necessità aperte della valigia AI, ordinate per categoria.
class SlotsSection extends StatelessWidget {
  final TripModel trip;
  final SlotActions actions;

  const SlotsSection({super.key, required this.trip, required this.actions});

  @override
  Widget build(BuildContext context) {
    final result = trip.aiResult!;
    final slots = (result.slots ?? const <AiSlot>[]).where((s) => s.isOpen);
    if (!slots.any((slot) => slot.isOpen)) {
      return const EmptySuitcase();
    }
    final gap = SizedBox(height: context.spacingSm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in result.notes) TripNoteRow(note: note),
        TripKitRow(
          trip: trip,
          flyKitItems: actions.flyKitItems,
          changeTrip: actions.changeTrip,
        ),
        for (final category in ItemCategory.values)
          ..._group(
            context,
            slots: slots.where((s) => s.category == category).toList(),
            count: slots.where((s) => s.category == category).length,
            header: category.displayName,
            sorting: true,
            gap: gap,
          ),
      ],
    );
  }

  Widget _important(AiSlot slot) {
    if (slot.toBuy) {
      return ToBuySlotRow(
        key: Key('slot_to_buy_row_${slot.id}'),
        slot: slot,
        onGotIt: () => actions.open(slot),
        onRemove: () => actions.remove(slot),
      );
    }
    return ImportantSlotCard(
      key: Key('slot_card_${slot.id}'),
      slot: slot,
      onAdd: () => actions.open(slot),
      onToBuy: () => actions.markToBuy(slot),
      onRemove: () => actions.remove(slot),
    );
  }

  List<Widget> _group(
    BuildContext context, {
    required List<AiSlot> slots,
    required int count,
    required String header,
    required bool sorting,
    required Widget gap,
  }) {
    final toBuy = slots.where((s) => s.toBuy);
    final important = slots.where(
      (s) => s.level == AiSlotLevel.important && !s.toBuy,
    );
    final useful = slots
        .where((s) => s.level == AiSlotLevel.useful && !s.toBuy)
        .toList();
    final blocks = <Widget>[
      for (final slot in important.where((s) => !s.toBuy)) _important(slot),
      if (useful.isNotEmpty)
        ProposedSlotsCard(
          slots: useful,
          sorting: sorting,
          onOpen: actions.open,
          onToggle: actions.toggle,
          onRemove: actions.dismiss,
        ),
      for (final slot in toBuy) _important(slot),
    ];
    if (blocks.isEmpty) return const [];

    return [
      DsGroupHeader(label: header, count: count),
      for (var i = 0; i < blocks.length; i++) ...[if (i > 0) gap, blocks[i]],
    ];
  }
}

class TripSlotsContext extends StatelessWidget {
  final TripModel trip;
  final SlotActions actions;

  const TripSlotsContext({
    super.key,
    required this.trip,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final notes = trip.aiResult?.notes ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in notes) TripNoteRow(note: note),
        TripKitRow(
          trip: trip,
          flyKitItems: actions.flyKitItems,
          changeTrip: actions.changeTrip,
        ),
      ],
    );
  }
}
