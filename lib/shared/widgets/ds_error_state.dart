import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'ds_empty_state.dart';
import 'ds_button.dart';

/// Widget standardizzato per stati di errore.
///
/// Mostra un'icona di errore, un messaggio e un bottone "Riprova".
///
/// Gli stili (colori, dimensioni, font) vengono letti dal tema tramite
/// `ErrorEmptyThemeExtension`, ma possono essere sovrascritti tramite i
/// parametri opzionali.
///
/// Esempio base (usa stili dal tema):
/// ```dart
/// DsErrorState(
///   error: error.toString(),
///   onRetry: () => ref.read(provider.notifier).refresh(),
/// )
/// ```
class DsErrorState extends StatelessWidget {
  /// Oggetto errore o messaggio di errore
  final Object error;

  /// Callback chiamato quando l'utente preme "Riprova"
  final VoidCallback onRetry;

  /// Spiegazione per l’utente. L’eccezione [error] non viene mai mostrata.
  final String? message;

  /// Titolo comprensibile, senza dettagli dell’eccezione.
  final String? title;

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

  /// Se false, il pulsante di retry non viene mostrato.
  ///
  /// Serve per gli errori che riprovare non può risolvere — quota esaurita,
  /// sessione scaduta: un "Riprova" lì è una promessa che il sistema non può
  /// mantenere.
  final bool showRetry;

  const DsErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    this.message,
    this.title,
    this.icon,
    this.iconColor,
    this.messageStyle,
    this.iconSize,
    this.retryLabel,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      scrollable: true,
      icon: icon ?? Icons.error_outline,
      iconColor: iconColor,
      iconSize: iconSize,
      title: title ?? 'errors.load_failed'.tr(),
      subtitle: message ?? (showRetry ? 'errors.retry_hint'.tr() : null),
      subtitleStyle: messageStyle,
      ctaLabel: showRetry ? retryLabel ?? 'common.retry'.tr() : null,
      ctaIcon: Icons.refresh,
      ctaVariant: DsButtonVariant.secondary,
      onCta: showRetry ? onRetry : null,
    );
  }
}

/// Alias legacy. I nuovi call site usano [DsErrorState].
@Deprecated('Use DsErrorState')
typedef ErrorState = DsErrorState;
