/// Helper centralizzato per tutti gli SnackBar dell'applicazione.
///
/// Garantisce uno stile visivo coerente in tutta l'app:
/// - **success / info**: sfondo `colorScheme.primary`, testo `colorScheme.onPrimary`.
/// - **error**: sfondo `colorScheme.error`, testo `colorScheme.onError`.
/// - **warning**: sfondo `colorScheme.tertiary`, testo `colorScheme.onTertiary`.
///
/// Tutti i messaggi usano `SnackBarBehavior.floating` per un aspetto moderno
/// e coerente con Material 3.
///
/// Esempio d'uso:
/// ```dart
/// AppSnackBar.showSuccess(context, 'Oggetto salvato!');
/// AppSnackBar.showError(context, 'Errore durante il salvataggio.');
/// ```
library;

import 'package:flutter/material.dart';

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

  // ── Internal ────────────────────────────────────────────────────────────────

  static void _show({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required Color textColor,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(context.spacingMd),
        ),
      );
  }
}
