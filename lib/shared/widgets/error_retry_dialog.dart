import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'ds_button.dart';
import 'ds_dialog.dart';
import 'ds_text_button.dart';

/// Risultato del dialog di errore.
enum ErrorDialogResult {
  /// L'utente ha scelto di riprovare
  retry,

  /// L'utente ha annullato
  cancel,
}

/// Helper per mostrare dialog di errore con opzione di retry.
///
/// Uso:
/// ```dart
/// final result = await ErrorRetryDialog.show(
///   context: context,
///   title: 'Errore di salvataggio',
///   message: 'Impossibile salvare il viaggio. Vuoi riprovare?',
/// );
/// if (result == ErrorDialogResult.retry) {
///   // Riprova l'operazione
/// }
/// ```
class ErrorRetryDialog {
  /// Mostra un dialog di errore con opzione di retry.
  ///
  /// Ritorna [ErrorDialogResult.retry] se l'utente vuole riprovare,
  /// [ErrorDialogResult.cancel] se annulla.
  static Future<ErrorDialogResult> show({
    required BuildContext context,
    String? title,
    required String message,
    String? retryText,
    String? cancelText,
    IconData icon = Icons.error_outline,
    Color? iconColor,
  }) async {
    final result = await showDsDialog<ErrorDialogResult>(
      context,
      barrierDismissible: false,
      builder: (context) => _ErrorDialog(
        title: title,
        message: message,
        retryText: retryText,
        cancelText: cancelText,
        icon: icon,
        iconColor: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    return result ?? ErrorDialogResult.cancel;
  }

  /// Esegue un'operazione con gestione automatica degli errori e retry.
  ///
  /// Se l'operazione fallisce, mostra un dialog che chiede se riprovare.
  /// Continua a riprovare finché l'utente non annulla o l'operazione ha successo.
  ///
  /// Ritorna `true` se l'operazione è riuscita, `false` se l'utente ha annullato.
  ///
  /// Uso:
  /// ```dart
  /// final success = await ErrorRetryDialog.executeWithRetry(
  ///   context: context,
  ///   operation: () => repository.saveTrip(trip),
  ///   errorMessage: 'Impossibile salvare il viaggio',
  /// );
  /// if (success) {
  ///   Navigator.pop(context);
  /// }
  /// ```
  static Future<bool> executeWithRetry({
    required BuildContext context,
    required Future<void> Function() operation,
    String? errorTitle,
    required String errorMessage,
    VoidCallback? onSuccess,
  }) async {
    while (true) {
      try {
        await operation();
        onSuccess?.call();
        return true;
      } catch (e) {
        debugPrint('[ErrorRetryDialog] Operazione fallita: $e');

        if (!context.mounted) return false;

        final result = await show(
          context: context,
          title: errorTitle,
          message: '$errorMessage\n\n${'common.retry_question'.tr()}',
        );

        if (result == ErrorDialogResult.cancel) {
          return false;
        }
        // Se retry, continua il loop
      }
    }
  }
}

class _ErrorDialog extends StatelessWidget {
  final String? title;
  final String message;
  final String? retryText;
  final String? cancelText;
  final IconData icon;
  final Color iconColor;

  const _ErrorDialog({
    required this.title,
    required this.message,
    required this.retryText,
    required this.cancelText,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return DsDialog(
      icon: icon,
      iconColor: iconColor,
      title: title ?? 'common.error'.tr(),
      message: message,
      // Le due uscite al centro, vicine e non divise a metà. Se non entrano
      // in una riga vanno a capo, come faceva l'AlertDialog di prima.
      actions: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: context.spacingSm,
          runSpacing: context.spacingSm,
          children: [
            DsTextButton(
              onPressed: () => Navigator.pop(context, ErrorDialogResult.cancel),
              label: cancelText ?? 'common.cancel'.tr(),
            ),
            DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: () => Navigator.pop(context, ErrorDialogResult.retry),
              icon: Icons.refresh,
              label: retryText ?? 'common.retry'.tr(),
            ),
          ],
        ),
      ],
    );
  }
}
