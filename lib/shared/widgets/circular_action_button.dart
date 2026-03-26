import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Bottone circolare per azioni secondarie nelle action bar.
/// 
/// Fornisce un design consistente per azioni laterali (delete, add, edit)
/// con supporto per:
/// - Icona personalizzabile
/// - Colore custom o da theme
/// - Bordo e elevazione
/// - Stato disabled
/// 
/// Esempio:
/// ```dart
/// CircularActionButton(
///   icon: Icons.delete,
///   onPressed: () => _delete(),
///   color: Colors.red,
/// )
/// ```
class CircularActionButton extends StatelessWidget {
  /// Icona da mostrare
  final IconData icon;

  /// Callback quando premuto
  final VoidCallback? onPressed;

  /// Colore icona custom (default: onSurfaceVariant)
  final Color? color;

  /// Colore background (default: surface)
  final Color? backgroundColor;

  /// Mostra bordo (default: true)
  final bool showBorder;

  /// Elevazione (default: 2)
  final double elevation;

  /// Dimensione bottone (default: 56)
  final double size;

  const CircularActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.showBorder = true,
    this.elevation = 2,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    final iconColor = isEnabled
        ? (color ?? colorScheme.onSurfaceVariant)
        : colorScheme.onSurface.withValues(alpha: 0.3);
    
    // CRITICAL: Bordo sempre BIANCO per i bottoni circolari
    final borderColor = isEnabled
        ? colorScheme.onSurface.withValues(alpha: 0.15)
        : colorScheme.onSurface.withValues(alpha: 0.1);

    return Material(
      color: backgroundColor ?? colorScheme.surface,
      shape: const CircleBorder(),
      elevation: isEnabled ? elevation : 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(
                    color: borderColor,
                    width: 2,
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: context.iconSizeMd,
          ),
        ),
      ),
    );
  }
}
