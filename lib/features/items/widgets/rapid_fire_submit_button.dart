import 'package:flutter/material.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_spacing.dart';

/// Bottone tondo "invia" del rapid fire: arancio se attivo, neutro se no,
/// con l'indicatore di avanzamento mentre salva.
class RapidFireSubmitButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final bool isSubmitting;

  const RapidFireSubmitButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = enabled
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final iconColor = enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: context.iconSizeLg,
        height: context.iconSizeLg,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: isSubmitting
            ? Padding(
                padding: EdgeInsets.all(context.spacingXs),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(
                Icons.arrow_upward,
                size: context.iconSizeSm,
                color: iconColor,
              ),
      ),
    );
  }
}
