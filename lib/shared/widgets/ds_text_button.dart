import 'package:flutter/material.dart';

import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Bottone di solo testo, con un'icona opzionale. È l'unico modo di scrivere
/// un `TextButton` nell'app.
///
/// Il testo è `onSurface` con peso w600; con [destructive] è `error`. Da
/// spento diventa `onSurface` al 50% (AppOpacity.disabled). [iconAtEnd] mette l'icona a destra del
/// testo, come la freccia dei link.
class DsTextButton extends StatelessWidget {
  final String label;

  /// `null` spegne il bottone.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Icona dopo il testo, come la freccia di [DsLinkButton].
  final bool iconAtEnd;

  /// Testo e icona in `error`, per le azioni distruttive.
  final bool destructive;

  const DsTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAtEnd = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;

    final color = !isEnabled
        ? colorScheme.onSurface.withValues(alpha: AppOpacity.disabled)
        : destructive
        ? colorScheme.error
        : colorScheme.onSurface;

    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.strong.copyWith(color: color);

    final text = Text(label, style: textStyle);

    final content = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!iconAtEnd) ...[
                Icon(icon, color: color, size: context.iconSizeSm),
                SizedBox(width: context.spacingSm),
              ],
              Flexible(child: text),
              if (iconAtEnd) ...[
                SizedBox(width: context.spacingSm),
                Icon(icon, color: color, size: context.iconSizeSm),
              ],
            ],
          );

    return TextButton(
      style: TextButton.styleFrom(
        // Anche il ripple prende il colore del testo, non l'arancio del tema.
        foregroundColor: color,
        minimumSize: const Size(
          kMinInteractiveDimension,
          kMinInteractiveDimension,
        ),
      ),
      onPressed: onPressed,
      child: content,
    );
  }
}
