import 'package:flutter/material.dart';
import '../theme/error_empty_theme_extension.dart';

/// Widget standardizzato per stati vuoti.
/// 
/// Mostra un'icona, un titolo, un sottotitolo opzionale e un'azione opzionale
/// in un layout verticale centrato.
/// 
/// Gli stili (colori, dimensioni, font) vengono letti dal tema tramite `ErrorEmptyThemeExtension`,
/// ma possono essere sovrascritti tramite i parametri opzionali.
/// 
/// Esempio base (usa stili dal tema):
/// ```dart
/// DsEmptyState(
///   icon: Icons.home_outlined,
///   title: 'Nessuna casa',
///   subtitle: 'Aggiungi la tua prima casa',
/// )
/// ```
/// 
/// Esempio con override:
/// ```dart
/// DsEmptyState(
///   icon: Icons.home_outlined,
///   title: 'Nessuna casa',
///   iconColor: Colors.blue,  // Override del colore dal tema
/// )
/// ```
class EmptyState extends StatelessWidget {
  /// Icona da mostrare in alto
  final IconData icon;
  
  /// Titolo principale
  final String title;
  
  /// Sottotitolo opzionale
  final String? subtitle;
  
  /// Widget azione opzionale (es: bottone)
  final Widget? action;
  
  /// Colore dell'icona (se null, usa il colore dal tema)
  final Color? iconColor;
  
  /// Stile del titolo (se null, usa lo stile dal tema)
  final TextStyle? titleStyle;
  
  /// Stile del sottotitolo (se null, usa lo stile dal tema)
  final TextStyle? subtitleStyle;
  
  /// Dimensione dell'icona (se null, usa la dimensione dal tema)
  final double? iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
    this.titleStyle,
    this.subtitleStyle,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.errorEmptyTheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          if (subtitle != null) ...[
            SizedBox(height: theme.stateSpacingSm),
            Text(
              subtitle!,
              style: subtitleStyle ?? theme.emptyStateSubtitle,
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
  }
}
