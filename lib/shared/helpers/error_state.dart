import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/error_empty_theme_extension.dart';

/// Widget standardizzato per stati di errore.
/// 
/// Mostra un'icona di errore, un messaggio e un bottone "Riprova".
/// 
/// Gli stili (colori, dimensioni, font) vengono letti dal tema tramite `ErrorEmptyThemeExtension`,
/// ma possono essere sovrascritti tramite i parametri opzionali.
/// 
/// Esempio base (usa stili dal tema):
/// ```dart
/// DsErrorState(
///   error: error.toString(),
///   onRetry: () => ref.read(provider.notifier).refresh(),
/// )
/// ```
/// 
/// Esempio con override:
/// ```dart
/// DsErrorState(
///   error: error,
///   onRetry: () => ...,
///   message: 'Qualcosa è andato storto',
///   icon: Icons.warning,
/// )
/// ```
class ErrorState extends StatelessWidget {
  /// Oggetto errore o messaggio di errore
  final Object error;
  
  /// Callback chiamato quando l'utente preme "Riprova"
  final VoidCallback onRetry;
  
  /// Messaggio personalizzato (se null, mostra "Errore: $error")
  final String? message;
  
  /// Icona personalizzata (se null, usa Icons.error_outline)
  final IconData? icon;
  
  /// Colore icona personalizzato (se null, usa il colore dal tema)
  final Color? iconColor;
  
  /// Stile del messaggio personalizzato (se null, usa lo stile dal tema)
  final TextStyle? messageStyle;
  
  /// Dimensione icona personalizzata (se null, usa la dimensione dal tema)
  final double? iconSize;
  
  /// Label bottone personalizzata (se null, usa la label dal tema)
  final String? retryLabel;

  const ErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    this.message,
    this.icon,
    this.iconColor,
    this.messageStyle,
    this.iconSize,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.errorEmptyTheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            size: iconSize ?? theme.errorStateIconSize,
            color: iconColor ?? theme.errorStateIconColor,
          ),
          SizedBox(height: theme.stateSpacingMd),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.stateSpacingMd),
            child: Text(
              message ?? '${'common.error_prefix'.tr()} $error',
              style: messageStyle ?? theme.errorStateMessage,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: theme.stateSpacingMd),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(retryLabel ?? theme.errorStateRetryLabel.tr()),
          ),
        ],
      ),
    );
  }
}
