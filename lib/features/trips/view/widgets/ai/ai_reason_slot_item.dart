import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/ai_packing.dart';
import '../slots/slot_copies_label.dart';

/// Un posto ancora aperto nel foglio dei motivi: nome, "×N" se le copie da
/// riempire sono più d'una, e sotto il motivo (assente: solo il nome).
class AiReasonSlotItem extends StatelessWidget {
  const AiReasonSlotItem({super.key, required this.slot});

  final AiSlot slot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = slotCopiesLabel(slot);
    final reason = slot.reason;

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copies == null ? slot.name : '${slot.name} $copies',
            style: tt.titleMedium?.title,
          ),
          if (reason != null && reason.isNotEmpty) ...[
            SizedBox(height: context.spacingXs),
            Text(
              reason,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
