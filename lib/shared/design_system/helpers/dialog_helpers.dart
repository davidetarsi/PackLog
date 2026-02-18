import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Helper per i dialog comuni dell'applicazione.
class DialogHelpers {
  DialogHelpers._();

  /// Mostra un dialog di conferma eliminazione.
  /// 
  /// Ritorna `true` se l'utente conferma, `false` altrimenti.
  /// 
  /// Esempio:
  /// ```dart
  /// final confirmed = await DialogHelpers.showDeleteConfirmation(
  ///   context: context,
  ///   itemType: 'casa',
  ///   itemName: house.name,
  /// );
  /// if (confirmed) {
  ///   // Procedi con l'eliminazione
  /// }
  /// ```
  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required String itemType,
    required String itemName,
    String? customMessage,
    String? customTitle,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(customTitle ?? 'Elimina $itemType'),
        content: Text(
          customMessage ?? 'Sei sicuro di voler eliminare "$itemName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Elimina',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Mostra un dialog generico di conferma.
  /// 
  /// Ritorna `true` se l'utente conferma, `false` altrimenti.
  /// 
  /// Esempio:
  /// ```dart
  /// final confirmed = await DialogHelpers.showConfirmation(
  ///   context: context,
  ///   title: 'Conferma azione',
  ///   message: 'Sei sicuro?',
  ///   confirmLabel: 'Sì',
  ///   cancelLabel: 'No',
  /// );
  /// ```
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Conferma',
    String cancelLabel = 'Annulla',
    bool isDestructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: isDestructive
                  ? const TextStyle(color: AppColors.destructive)
                  : null,
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Mostra un dialog informativo con un solo bottone "OK".
  /// 
  /// Esempio:
  /// ```dart
  /// await DialogHelpers.showInfo(
  ///   context: context,
  ///   title: 'Impossibile eliminare',
  ///   message: 'La casa contiene oggetti.',
  /// );
  /// ```
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String okLabel = 'OK',
    IconData? icon,
    Color? iconColor,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: iconColor ?? AppColors.warning,
                size: 48,
              ),
              const SizedBox(height: 16),
            ],
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }
}
