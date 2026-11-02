import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';

/// Pillola neutra con un'attività o un mezzo del kit: solo lettura, bordo
/// sottile e testo secondario. I kit non hanno colore proprio.
class KitUsePill extends StatelessWidget {
  const KitUsePill({super.key, required this.label, this.semanticsLabel});

  final String label;

  /// Cosa legge il lettore di schermo, se il testo da solo non basta ("+2").
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingXxs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: AppConstants.hairlineBorderWidth,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
