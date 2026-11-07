import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/ai_packing.dart';
import '../slots/slot_copies_label.dart';

/// Un posto ancora aperto nel foglio dei motivi: nome, "×N" se le copie da
/// riempire sono più d'una, e sotto il motivo (assente o nascosto: solo il
/// nome).
class AiReasonSlotItem extends StatelessWidget {
  const AiReasonSlotItem({
    super.key,
    required this.slot,
    this.showReason = true,
  });

  final AiSlot slot;

  /// I suggeriti non mostrano il motivo: la sezione lo dice una volta sola.
  final bool showReason;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = slotCopiesLabel(slot);
    final reason = showReason ? slot.reason : null;

    return Padding(
      padding: EdgeInsets.all(context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copies == null ? slot.name : '${slot.name} $copies',
            style: tt.bodyLarge?.strong,
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
