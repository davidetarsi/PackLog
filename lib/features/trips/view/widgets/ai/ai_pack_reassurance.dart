import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Una riga che rassicura, sotto il titolo della valigia AI: la valigia ha
/// già il necessario, il resto si aggiunge dalla ricerca.
class AiPackReassurance extends StatelessWidget {
  const AiPackReassurance({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'trips.pack.ai.reassurance'.tr(),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
