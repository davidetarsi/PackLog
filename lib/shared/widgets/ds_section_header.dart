import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Header di sezione riusabile con due varianti visive.
///
/// Variante **text-only** (settings, lista generica):
/// ```dart
/// DsSectionHeader(label: 'backup.title'.tr())
/// DsSectionHeader(label: 'about.title'.tr(), trailing: Icon(Icons.info))
/// ```
///
/// Variante **icon-text** (gruppi di contenuto con icona):
/// ```dart
/// DsSectionHeader.withIcon(icon: Icons.star, label: 'Preferiti')
/// DsSectionHeader.withIcon(icon: Icons.luggage, label: 'Bagagli', trailing: badge)
/// ```
///
/// Regola tipografica (DS Fase 3 §3.2): 14px → FontWeight.w500.
/// Colore di default: `colorScheme.primary` (per entrambe le varianti).
class DsSectionHeader extends StatelessWidget {
  /// Testo del header.
  final String label;

  /// Icona opzionale (variante icon-text). Se null: modalità text-only.
  final IconData? icon;

  /// Widget opzionale a destra (es. badge, count, action button).
  final Widget? trailing;

  /// Colore dell'icona e del testo. Default: `colorScheme.primary`.
  final Color? color;

  /// Padding personalizzato. Se null, usa `horizontal=spacingMd, vertical=spacingSm`.
  final EdgeInsetsGeometry? padding;

  const DsSectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.color,
    this.padding,
  });

  /// Costruttore named per la variante **icon-text** esplicita.
  const DsSectionHeader.withIcon({
    super.key,
    required this.label,
    required IconData this.icon,
    this.trailing,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingSm,
          ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.responsive(20), color: effectiveColor),
            SizedBox(width: context.spacingSm),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize:
                    context.fontSizeXs, // 14px → w500 (regola DS size→weight)
                fontWeight: FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.spacingSm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
