import 'package:flutter/material.dart';
import '../../../shared/theme/app_opacity.dart';
import '../../../shared/theme/app_spacing.dart';

/// "×N" accanto al bottone invia: fondo tenue dell'arancio, mai pieno (l'arancio
/// pieno è del bottone).
class RapidFireCopiesPill extends StatelessWidget {
  final int copies;
  final VoidCallback onTap;

  const RapidFireCopiesPill({
    super.key,
    required this.copies,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: BoxConstraints(minHeight: context.iconSizeLg),
          padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: AppOpacity.selected),
            borderRadius: BorderRadius.circular(context.iconSizeLg / 2),
          ),
          child: Text(
            '×$copies',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
