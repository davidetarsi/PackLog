import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../model/ai_packing.dart';
import 'slot_copies_label.dart';

/// Riga di un posto segnato da comprare. Il pulsante apre il foglio di
/// riempimento; la X lo rimuove dal viaggio.
class ToBuySlotRow extends StatelessWidget {
  const ToBuySlotRow({
    super.key,
    required this.slot,
    required this.onGotIt,
    this.onRemove,
  });

  final AiSlot slot;
  final VoidCallback onGotIt;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = slotCopiesLabel(slot);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXs),
      child: Row(
        children: [
          if (onRemove != null)
            DsIconButton(
              key: Key('slot_not_useful_${slot.id}'),
              icon: Icons.close,
              tooltip: 'trips.slots.not_useful'.tr(),
              onPressed: onRemove,
            ),
          Expanded(
            child: Text(
              slot.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyLarge,
            ),
          ),
          if (copies != null) ...[
            SizedBox(width: context.spacingXs),
            Text(
              copies,
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          DsTextButton(
            key: Key('slot_got_it_${slot.id}'),
            label: slot.boughtLabel ?? 'trips.slots.bought_fallback'.tr(),
            onPressed: onGotIt,
          ),
        ],
      ),
    );
  }
}
