import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Helper per i dialog comuni dell'applicazione.
///
/// Convenzione bottoni:
/// - Annulla / secondario → TextButton (colore default)
/// - Azione distruttiva   → TextButton (foregroundColor: error)
/// - Azione primaria neutra → FilledButton (primary)
class DialogHelpers {
  DialogHelpers._();

  /// Mostra un dialog di conferma eliminazione.
  ///
  /// [warningText] aggiunge una riga di avviso rossa sotto il messaggio principale
  /// (es. "questo bagaglio verrà rimosso da tutti i viaggi").
  ///
  /// Ritorna `true` se l'utente conferma, `false` altrimenti.
  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required String itemType,
    required String itemName,
    String? customMessage,
    String? customTitle,
    String? warningText,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(
            customTitle ?? 'dialogs.delete_title'.tr(args: [itemType]),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customMessage ??
                    'dialogs.delete_message'.tr(args: [itemName]),
              ),
              if (warningText != null) ...[
                SizedBox(height: 12),
                Text(
                  warningText,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('dialogs.cancel'.tr()),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('dialogs.delete_confirm'.tr()),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  /// Mostra un dialog generico di conferma.
  ///
  /// [isDestructive] usa TextButton rosso per il bottone di conferma.
  /// Altrimenti usa FilledButton (primary).
  ///
  /// Ritorna `true` se l'utente conferma, `false` altrimenti.
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
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
            child: Text(cancelLabel ?? 'common.cancel'.tr()),
          ),
          if (isDestructive)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel ?? 'common.confirm'.tr()),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel ?? 'common.confirm'.tr()),
            ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Mostra un dialog informativo con un solo bottone "OK".
  ///
  /// [icon] opzionale viene mostrata sopra il messaggio.
  /// [details] aggiunge bullet point rossi sotto il messaggio principale
  /// (es. conteggio oggetti quando non si può eliminare una casa).
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? okLabel,
    IconData? icon,
    Color? iconColor,
    List<String>? details,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Center(
                  child: Icon(
                    icon,
                    color: iconColor ??
                        theme.extension<AppColorsExtension>()!.warning,
                    size: 48,
                  ),
                ),
                SizedBox(height: 16),
              ],
              Text(message),
              if (details != null && details.isNotEmpty) ...[
                SizedBox(height: 12),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $detail',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(okLabel ?? 'common.ok'.tr()),
            ),
          ],
        );
      },
    );
  }
}
