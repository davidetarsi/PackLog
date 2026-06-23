import 'package:flutter/material.dart';
import 'package:pack_log/shared/widgets/tri_slot_bar.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Action bar universale con bottone primario centrato perfettamente.
///
/// Fornisce un layout consistente per le azioni bottom delle schermate:
/// - Bottone primario (center) sempre perfettamente centrato
/// - Azioni laterali opzionali (left/right) che non influenzano la centratura
/// - Elevazione e stile pill consistenti
///
/// **Pattern Critico di Centratura:**
/// Usa `Expanded` + `Align` per i slot laterali, garantendo che il
/// bottone centrale rimanga perfettamente centrato anche quando
/// left/right sono null.
///
/// Esempio:
/// ```dart
/// UniversalActionBar(
///   primaryLabel: 'Continua',
///   onPrimaryPressed: () => _next(),
///   leftAction: CircularActionButton(icon: Icons.delete, ...),
///   rightAction: CircularActionButton(icon: Icons.edit, ...),
/// )
/// ```
class UniversalActionBar extends StatelessWidget {
  /// Label del bottone primario centrale
  final String primaryLabel;

  /// Callback per il bottone primario
  final VoidCallback? onPrimaryPressed;

  /// Icona opzionale per il bottone primario
  final IconData? primaryIcon;

  /// Widget azione sinistra (es: CircularActionButton per delete)
  final Widget? leftAction;

  /// Widget azione destra (es: CircularActionButton per add/edit)
  final Widget? rightAction;

  /// Mostra loading indicator nel bottone primario
  final bool isLoading;

  /// Usa bordo outline (grigio) invece di primary. Per azioni secondarie/distruttive
  /// che non devono richiamare l'attenzione come un'azione primaria.
  final bool isSecondary;

  /// Usa bordo e testo rosso (colorScheme.error). Per azioni irreversibili
  /// come l'eliminazione dell'account.
  final bool isDestructive;

  const UniversalActionBar({
    super.key,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.primaryIcon,
    this.leftAction,
    this.rightAction,
    this.isLoading = false,
    this.isSecondary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSingleAction = leftAction == null && rightAction == null;

    final primaryButton = _PrimaryPillButton(
      label: primaryLabel,
      icon: primaryIcon,
      onPressed: onPrimaryPressed,
      isLoading: isLoading,
      colorScheme: colorScheme,
      isFullWidth: isSingleAction,
      isSecondary: isSecondary,
      isDestructive: isDestructive,
    );

    return TriSlotBar(
      horizontalPadding: 0,
      left: leftAction,
      right: rightAction,
      center: primaryButton,
    );
  }
}

/// Bottone primario centrale in stile pill.
class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ColorScheme colorScheme;
  final bool isFullWidth;
  final bool isSecondary;
  final bool isDestructive;

  const _PrimaryPillButton({
    required this.label,
    this.icon,
    this.onPressed,
    required this.isLoading,
    required this.colorScheme,
    this.isFullWidth = false,
    this.isSecondary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    final Color accentColor;
    if (!isEnabled) {
      accentColor = colorScheme.outline;
    } else if (isDestructive) {
      accentColor = colorScheme.error;
    } else if (isSecondary) {
      accentColor = colorScheme.outline;
    } else {
      accentColor = colorScheme.primary;
    }

    final Color contentColor = isDestructive && isEnabled
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      // elevation: 0 elimina il layer di ombra nel compositing: quando la barra
      // fluttua sopra liste scorrevoli, ogni frame non richiede un shadow pass
      // separato sull'engine Impeller.
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        onTap: isEnabled ? onPressed : null,
        child: Container(
          width: isFullWidth ? double.infinity : null,
          height: context.responsive(56),
          padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
          decoration: BoxDecoration(
            // Nessun colore qui: il colore di sfondo è già gestito da Material.
            // Aggiungere color in BoxDecoration causerebbe un layer di pittura
            // aggiuntivo sovrapposto a quello di Material.
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
            border: Border.all(color: accentColor, width: 2),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: context.responsive(24),
                    height: context.responsive(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                      // strokeAlignCenter evita artefatti di anti-aliasing
                      // sul bordo esterno durante l'animazione di rotazione.
                      strokeAlign: CircularProgressIndicator.strokeAlignCenter,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: contentColor, size: context.iconSizeMd),
                      SizedBox(width: context.spacingSm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: contentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
