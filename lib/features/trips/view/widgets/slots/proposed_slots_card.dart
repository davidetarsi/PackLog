import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../model/ai_packing.dart';
import 'proposed_slot_row.dart';

/// Card dei proposti di PackLog in un gruppo: bordo col gradiente, fermo;
/// in cima la scintilla e "Proposti da PackLog · tocca per mettere i tuoi".
///
/// Ogni riga ha la scintilla, il nome, ×N e la freccina; quando non si sta
/// più sistemando ([sorting] falso) al posto della scintilla c'è la casella,
/// che cambia `checked`. Il tocco sulla riga chiama [onOpen]; scorrerla
/// verso sinistra la toglie ([onRemove]).
class ProposedSlotsCard extends StatelessWidget {
  const ProposedSlotsCard({
    super.key,
    required this.slots,
    required this.sorting,
    required this.onOpen,
    required this.onToggle,
    this.onRemove,
  });

  final List<AiSlot> slots;
  final bool sorting;
  final ValueChanged<AiSlot> onOpen;
  final ValueChanged<AiSlot> onToggle;

  /// Chiamata quando una riga viene scorsa verso sinistra; `null` non le
  /// rende scorrevoli.
  final ValueChanged<AiSlot>? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final remove = onRemove;

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
                children: [
                  PackLogSparkle(size: context.iconSizeSm),
                  SizedBox(width: context.spacingXs),
                  Expanded(
                    child: Text(
                      'trips.slots.proposed_header'.tr(),
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final slot in slots)
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
            SizedBox(height: context.spacingXs),
          ],
        ),
      ),
    );
  }
}
