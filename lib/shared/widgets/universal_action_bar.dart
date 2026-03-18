import 'package:flutter/material.dart';
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

  /// Padding orizzontale esterno (default: spacingMd)
  final double? horizontalPadding;

  const UniversalActionBar({
    super.key,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.primaryIcon,
    this.leftAction,
    this.rightAction,
    this.isLoading = false,
    this.horizontalPadding,
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
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding ?? context.spacingMd,
      ),
      child: isSingleAction
          ? primaryButton
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Slot sinistro con SizedBox fissa
                SizedBox(
                  width: 56,
                  child: leftAction ?? const SizedBox.shrink(),
                ),

                SizedBox(width: context.spacingSm),

                // Bottone primario centrale (pill button) - Expanded
                Expanded(child: primaryButton),

                SizedBox(width: context.spacingSm),

                // Slot destro con SizedBox fissa
                SizedBox(
                  width: 56,
                  child: rightAction ?? const SizedBox.shrink(),
                ),
              ],
            ),
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

  const _PrimaryPillButton({
    required this.label,
    this.icon,
    this.onPressed,
    required this.isLoading,
    required this.colorScheme,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        onTap: isEnabled ? onPressed : null,
        child: Container(
          width: isFullWidth ? double.infinity : null,
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
            border: Border.all(
              color: isEnabled ? colorScheme.primary : colorScheme.outline,
              width: 2,
            ),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: colorScheme.onSurfaceVariant, size: context.iconSizeMd),
                      SizedBox(width: context.spacingSm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
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
