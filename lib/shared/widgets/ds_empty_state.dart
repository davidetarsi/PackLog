import 'package:flutter/material.dart';
import '../theme/error_empty_theme_extension.dart';

/// Widget standardizzato per stati vuoti.
///
/// Mostra un'icona, un titolo, un sottotitolo opzionale e un'azione opzionale
/// in un layout verticale centrato.
///
/// Esempio:
/// ```dart
/// DsEmptyState(
///   icon: Icons.home_outlined,
///   title: 'Nessuna casa',
///   subtitle: 'Aggiungi la tua prima casa',
/// )
/// ```
class DsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double? iconSize;

  /// Callback opzionale invocata al tap sull'intero widget.
  final VoidCallback? onTap;

  /// Testo del hint mostrato sotto il subtitle quando [onTap] è fornito.
  final String? tapHint;

  const DsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
    this.titleStyle,
    this.subtitleStyle,
    this.iconSize,
    this.onTap,
    this.tapHint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.errorEmptyTheme;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: theme.stateSpacingLg),
          Icon(
            icon,
            size: iconSize ?? theme.emptyStateIconSize,
            color: iconColor ?? theme.emptyStateIconColor,
          ),
          SizedBox(height: theme.stateSpacingMd),
          Text(
            title,
            style: titleStyle ?? theme.emptyStateTitle,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null && tapHint == null) ...[
            SizedBox(height: theme.stateSpacingSm),
            Text(
              subtitle!,
              style: subtitleStyle ?? theme.emptyStateSubtitle,
              textAlign: TextAlign.center,
            ),
          ],
          if (tapHint != null) ...[
            SizedBox(height: theme.stateSpacingSm),
            Text(
              tapHint!,
              style: theme.emptyStateSubtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            SizedBox(height: theme.stateSpacingLg),
            action!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    return content;
  }
}

/// Alias legacy. I nuovi call site usano [DsEmptyState].
@Deprecated('Use DsEmptyState')
typedef EmptyState = DsEmptyState;
