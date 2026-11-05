import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_checkbox.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../model/ai_packing.dart';
import 'slot_copies_label.dart';

/// Rende la riga di un proposto scorrevole verso sinistra: lo scorrimento
/// la toglie ([onRemove]). Con [onRemove] nullo la riga resta ferma.
class SwipeableSlotRow extends StatelessWidget {
  const SwipeableSlotRow({
    super.key,
    required this.slot,
    required this.onRemove,
    required this.child,
  });

  final AiSlot slot;
  final VoidCallback? onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remove = onRemove;
    if (remove == null) return child;
    return Dismissible(
      key: Key('slot_dismiss_${slot.id}'),
      direction: DismissDirection.endToStart,
      // Senza animazioni la riga scorre col dito, ma lo spazio si chiude
      // subito.
      resizeDuration: MediaQuery.disableAnimationsOf(context)
          ? null
          : AppMotion.slow,
      onDismissed: (_) => remove(),
      background: ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: context.spacingMd),
            child: Icon(Icons.close, color: cs.onSurfaceVariant),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// Una riga dei proposti: scintilla o casella, nome, "da comprare", ×N e
/// la freccina; il tocco chiama [onTap].
class ProposedSlotRow extends StatelessWidget {
  const ProposedSlotRow({
    super.key,
    required this.slot,
    required this.sorting,
    required this.onTap,
    required this.onToggle,
    this.onDismiss,
  });

  final AiSlot slot;
  final bool sorting;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = slotCopiesLabel(slot);
    final packed = !sorting && slot.checked;

    return InkWell(
      key: Key('slot_row_${slot.id}'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: context.spacingSm,
          right: context.spacingMd,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Row(
            children: [
              if (sorting)
                SizedBox.square(
                  dimension: kMinInteractiveDimension,
                  child: Center(
                    child: PackLogSparkle(size: context.iconSizeSm),
                  ),
                )
              else
                DsCheckbox(value: slot.checked, onChanged: (_) => onToggle()),
              SizedBox(width: context.spacingXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        color: packed ? context.textTertiary : cs.onSurface,
                        decoration: packed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (slot.toBuy)
                      Text(
                        'trips.slots.to_buy'.tr(),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (copies != null) ...[
                SizedBox(width: context.spacingSm),
                Text(
                  copies,
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              SizedBox(width: context.spacingXs),
              if (onDismiss != null)
                DsIconButton(
                  key: Key('slot_not_useful_${slot.id}'),
                  icon: Icons.close,
                  tooltip: 'trips.slots.not_useful'.tr(),
                  onPressed: onDismiss,
                  flushEnd: true,
                )
              else
                Icon(
                  Icons.chevron_right,
                  size: context.iconSizeMd,
                  color: cs.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
