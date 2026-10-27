import 'package:flutter/material.dart';

import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';

/// Bottone di sola icona. È l'unico modo di scrivere un `IconButton` nell'app.
///
/// Il [tooltip] è obbligatorio: è il nome del bottone per chi non vede l'icona,
/// e compare al tocco lungo. L'area di tocco è 48, l'icona `iconSizeMd`. Da
/// spento l'icona è `onSurface` al 38%.
class DsIconButton extends StatelessWidget {
  final IconData icon;

  /// Testo del tooltip, dal dizionario (`'common.close'.tr()`).
  final String tooltip;

  /// `null` spegne il bottone.
  final VoidCallback? onPressed;

  /// `null` usa il colore del tema dell'icona.
  final Color? color;

  const DsIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: context.iconSizeMd),
      color: color,
      disabledColor: colorScheme.onSurface.withValues(
        alpha: AppOpacity.disabled,
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(
          kMinInteractiveDimension,
          kMinInteractiveDimension,
        ),
      ),
      onPressed: onPressed,
    );
  }
}
