import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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
    final result = await showDialog<ErrorDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ErrorDialog(
        title: title,
        message: message,
        retryText: retryText,
        cancelText: cancelText,
        icon: icon,
        iconColor: iconColor ?? Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);
    
    return AlertDialog(
      icon: Icon(
        icon,
        size: 48,
        color: iconColor,
      ),
      title: Text(
        title ?? 'common.error'.tr(),
        textAlign: TextAlign.center,
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ErrorDialogResult.cancel),
          child: Text(cancelText ?? 'common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, ErrorDialogResult.retry),
          icon: const Icon(Icons.refresh),
          label: Text(retryText ?? 'common.retry'.tr()),
        ),
      ],
    );
  }
}
