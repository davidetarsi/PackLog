import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/ai_packing.dart';

/// Un'informazione sul viaggio ("Prevedi una lavanderia"): icona, titolo e
/// perché, con i testi del server.
class TripNoteRow extends StatelessWidget {
  const TripNoteRow({super.key, required this.note});

  final AiTripNote note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: context.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: context.iconSizeSm,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: tt.bodyLarge?.strong),
                SizedBox(height: context.spacingXxs),
                Text(
                  note.why,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
