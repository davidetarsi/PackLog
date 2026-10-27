/// Helper centralizzato per tutti gli SnackBar dell'applicazione.
///
/// Garantisce uno stile visivo coerente in tutta l'app:
/// - **success / info**: sfondo `colorScheme.primary`, testo `colorScheme.onPrimary`.
/// - **error**: sfondo `colorScheme.error`, testo `colorScheme.onError`.
/// - **warning**: sfondo `colorScheme.tertiary`, testo `colorScheme.onTertiary`.
///
/// Tutti i messaggi usano `SnackBarBehavior.floating` per un aspetto moderno
/// e coerente con Material 3. Il raggio è `AppConstants.inputBorderRadius`.
///
/// Esempio d'uso:
/// ```dart
/// AppSnackBar.showSuccess(context, 'Oggetto salvato!');
/// AppSnackBar.showError(context, 'Errore durante il salvataggio.');
/// ```
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Utility statica per mostrare SnackBar con lo stile del Design System.
class AppSnackBar {
  AppSnackBar._();

  /// Mostra uno SnackBar di **successo** con sfondo `colorScheme.primary`.
  ///
  /// Usare per confermare operazioni andate a buon fine (salvataggio,
  /// eliminazione, duplicazione, ecc.).
  static void showSuccess(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.primary,
      textColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  /// Mostra uno SnackBar di **errore** con sfondo `colorScheme.error`.
  ///
  /// Usare per segnalare operazioni fallite o input non validi.
  static void showError(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.error,
      textColor: Theme.of(context).colorScheme.onError,
    );
  }

  /// Come [showError], ma sul [messenger] passato invece che su un context.
  ///
  /// Serve quando il context della schermata può essere già smontato: il
  /// chiamante prende il messenger prima dell'operazione asincrona.
  static void showErrorOn(ScaffoldMessengerState messenger, String message) {
    final context = messenger.context;
    final colorScheme = Theme.of(context).colorScheme;
    _showOn(
      messenger,
      context: context,
      message: message,
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
    );
  }

  /// Mostra uno SnackBar di **avvertimento** con sfondo `colorScheme.tertiary`.
  ///
  /// Usare per segnalare situazioni anomale ma non bloccanti
  /// (es. campo obbligatorio mancante, data non valida).
  static void showWarning(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      textColor: Theme.of(context).colorScheme.onTertiary,
    );
  }

  /// Mostra uno SnackBar **informativo**, neutro (`inverseSurface`).
  ///
  /// Usare per avvisi che non sono né un successo né un problema
  /// (es. "funzione in arrivo").
  static void showInfo(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      textColor: Theme.of(context).colorScheme.onInverseSurface,
    );
  }

  /// Mostra uno SnackBar **informativo** con l'azione [actionLabel], neutro
  /// (`inverseSurface`) come [showInfo]. L'azione resta del colore del testo:
  /// lo SnackBar non è arancio.
  ///
  /// Se la pagina non ha uno `ScaffoldMessenger` (per esempio un'azione
  /// annullata durante il cambio di pagina) non mostra nulla e non lancia.
  static void showAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Key? key,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    _show(
      context: context,
      key: key,
      message: message,
      backgroundColor: colorScheme.inverseSurface,
      textColor: colorScheme.onInverseSurface,
      action: SnackBarAction(
        label: actionLabel,
        textColor: colorScheme.onInverseSurface,
        onPressed: onAction,
      ),
    );
  }

  /// Mostra uno SnackBar **informativo** con l'azione "Annulla" (`common.undo`),
  /// per tornare indietro su un'operazione appena fatta (es. capo tolto).
  static void showUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
  }) {
    showAction(
      context,
      message,
      actionLabel: 'common.undo'.tr(),
      onAction: onUndo,
    );
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  static void _show({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required Color textColor,
    SnackBarAction? action,
    Key? key,
  }) {
    // Senza ScaffoldMessenger non c'è dove mostrare lo SnackBar: si esce senza
    // errore, come per un'azione chiesta da una pagina già smontata.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _showOn(
      messenger,
      context: context,
      message: message,
      backgroundColor: backgroundColor,
      textColor: textColor,
      action: action,
      key: key,
    );
  }

  static void _showOn(
    ScaffoldMessengerState messenger, {
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required Color textColor,
    SnackBarAction? action,
    Key? key,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: key,
          content: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
          margin: EdgeInsets.all(context.spacingMd),
          action: action,
        ),
      );
  }
}
