import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_group_header.dart';
import '../../../../../shared/widgets/ds_section_title.dart';
import '../../../../items/model/item_model.dart';
import '../../../model/ai_packing.dart';
import '../../../model/suitcase_progress.dart';
import '../../../model/trip_model.dart';
import 'slot_widgets.dart';
import 'trip_items_card.dart';

/// Cosa si può fare sui posti della valigia; li gestisce lo schermo.
class SlotActions {
  const SlotActions({
    required this.open,
    required this.markToBuy,
    required this.toggle,
    required this.remove,
    required this.dismiss,
  });

  final ValueChanged<AiSlot> open;
  final ValueChanged<AiSlot> markToBuy;
  final ValueChanged<AiSlot> toggle;

  /// La X di un importante: chiede conferma prima di togliere.
  final ValueChanged<AiSlot> remove;

  /// Lo scorrimento di una proposta: toglie subito, con Annulla.
  final ValueChanged<AiSlot> dismiss;
}

/// "Cosa porti" con la valigia fatta di posti: la testata con l'avanzamento,
/// le informazioni sul viaggio, poi per categoria gli importanti aperti, i
/// "da comprare", la card dei proposti e gli oggetti dell'utente.
class SlotsSection extends StatelessWidget {
  final TripModel trip;
  final SlotActions actions;

  const SlotsSection({super.key, required this.trip, required this.actions});

  @override
  Widget build(BuildContext context) {
    final progress = SuitcaseProgress.of(trip);
    if (progress.isEmpty) return const EmptySuitcase();

    final result = trip.aiResult!;
    final open = (result.slots ?? const <AiSlot>[]).where((s) => s.inSuitcase);
    final gap = SizedBox(height: context.spacingSm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.pack.items'.tr()),
        SuitcaseProgressHeader(progress: progress),
        for (final note in result.notes) TripNoteRow(note: note),
        for (final category in ItemCategory.values)
          ..._group(
            context,
            category: category,
            slots: open.where((s) => s.category == category).toList(),
            items: trip.items.where((i) => i.category == category).toList(),
            sorting: progress.sorting,
            gap: gap,
          ),
      ],
    );
  }

  List<Widget> _group(
    BuildContext context, {
    required ItemCategory category,
    required List<AiSlot> slots,
    required List<TripItem> items,
    required bool sorting,
    required Widget gap,
  }) {
    if (slots.isEmpty && items.isEmpty) return const [];
    final important = slots.where((s) => s.level == AiSlotLevel.important);
    final toFill = important.where((s) => !s.toBuy);
    final toBuy = important.where((s) => s.toBuy);
    final useful = slots.where((s) => s.level == AiSlotLevel.useful).toList();

    final blocks = <Widget>[
      for (final slot in toFill)
        ImportantSlotCard(
          key: Key('slot_card_${slot.id}'),
          slot: slot,
          onAdd: () => actions.open(slot),
          onToBuy: () => actions.markToBuy(slot),
          onRemove: () => actions.remove(slot),
        ),
      for (final slot in toBuy)
        ToBuySlotRow(
          key: Key('slot_to_buy_row_${slot.id}'),
          slot: slot,
          onGotIt: () => actions.open(slot),
          onRemove: () => actions.remove(slot),
        ),
      if (useful.isNotEmpty)
        ProposedSlotsCard(
          slots: useful,
          sorting: sorting,
          onOpen: actions.open,
          onToggle: actions.toggle,
          onRemove: actions.dismiss,
        ),
      if (items.isNotEmpty) ItemsCard(tripId: trip.id, items: items),
    ];

    return [
      DsGroupHeader(
        label: category.displayName,
        count: slots.length + items.length,
      ),
      for (var i = 0; i < blocks.length; i++) ...[if (i > 0) gap, blocks[i]],
    ];
  }
}
