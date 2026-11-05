import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../model/ai_packing.dart';
import 'proposed_slot_row.dart';
import 'slot_focus.dart';
import 'slot_pop.dart';

/// Card dei proposti di PackLog in un gruppo: bordo col gradiente, fermo;
/// in cima la scintilla, "Suggeriti da PackLog" e il rapporto con l'inventario.
///
/// Ogni riga ha la scintilla, il nome, ×N e la freccina; quando non si sta
/// più sistemando ([sorting] falso) al posto della scintilla c'è la casella,
/// che cambia `checked`. Il tocco sulla riga chiama [onOpen]; scorrerla
/// verso sinistra la toglie ([onRemove]).
///
/// Con un posto aperto ([openSlotId] e [openBody]) il suo contenuto sale in
/// prima riga, su una superficie un gradino più chiara, e le altre righe si
/// spengono ([SlotFocus]): un tocco sopra chiama [onTapOutside].
class ProposedSlotsCard extends StatelessWidget {
  const ProposedSlotsCard({
    super.key,
    required this.slots,
    required this.sorting,
    required this.onOpen,
    required this.onToggle,
    this.onRemove,
    this.openSlotId,
    this.openBody,
    this.onTapOutside,
    this.popping = false,
    this.onPopDone,
  });

  final List<AiSlot> slots;
  final bool sorting;
  final ValueChanged<AiSlot> onOpen;
  final ValueChanged<AiSlot> onToggle;

  /// Chiamata quando una riga viene scorsa verso sinistra; `null` non le
  /// rende scorrevoli.
  final ValueChanged<AiSlot>? onRemove;

  /// Il posto aperto di questa card e il suo contenuto; `null` = nessuno.
  final String? openSlotId;
  final Widget? openBody;
  final VoidCallback? onTapOutside;

  /// Il posto aperto sta scoppiando: tutto il riquadro, sfondo compreso,
  /// si dissolve e poi chiama [onPopDone].
  final bool popping;
  final VoidCallback? onPopDone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final remove = onRemove;
    final open = openBody;

    return PackLogGradientBorder(
      radius: AppConstants.cardBorderRadius,
      width: AppConstants.hairlineBorderWidth,
      restingOpacity: AppOpacity.subtleGradientBorder,
      child: Material(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacingMd,
                context.spacingMd,
                context.spacingMd,
                context.spacingXs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PackLogSparkle(size: context.iconSizeSm),
                  SizedBox(width: context.spacingXs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'trips.slots.proposed_header'.tr(),
                          style: tt.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: context.spacingXxs),
                        Text(
                          'trips.slots.proposed_inventory'.tr(),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (open != null)
              SlotPop(
                popping: popping,
                onDone: onPopDone,
                child: _OpenRow(child: open),
              ),
            SlotFocus(
              active: open != null,
              onTapOutside: onTapOutside ?? () {},
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final slot in slots)
                    if (open == null || slot.id != openSlotId)
                      SwipeableSlotRow(
                        slot: slot,
                        onRemove: remove == null ? null : () => remove(slot),
                        child: ProposedSlotRow(
                          slot: slot,
                          sorting: sorting,
                          onTap: () => onOpen(slot),
                          onToggle: () => onToggle(slot),
                        ),
                      ),
                ],
              ),
            ),
            SizedBox(height: context.spacingXs),
          ],
        ),
      ),
    );
  }
}

/// La prima riga col posto aperto: un riquadro un gradino più chiaro della
/// card.
class _OpenRow extends StatelessWidget {
  const _OpenRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.nestedSurface,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.spacingSm),
          child: child,
        ),
      ),
    );
  }
}
