import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/entity_context_menu.dart';
import '../widgets/error_retry_dialog.dart';
import 'dialog_helpers.dart';
import 'snack_bar_helper.dart';

/// Centralizza la gestione delle azioni del context menu entità
/// (long-press su case, viaggi, card compact).
///
/// Ogni case del menu è orchestrato in modo uniforme:
/// - copy/save/setPrimary → [ErrorRetryDialog.executeWithRetry] + snackbar opzionale
/// - delete → [DialogHelpers.showDeleteConfirmation] poi executeWithRetry + snackbar opzionale
///
/// Le callback (onCopy, onDelete, …) contengono solo l'operazione asincrona pura;
/// tutto il feedback UX è gestito qui.
class EntityActionHandler {
  const EntityActionHandler._();

  static Future<void> handleAction({
    required BuildContext context,
    required EntityContextMenuAction action,
    required String entityTypeLabel,
    required String entityName,
    Future<void> Function()? onCopy,
    String copyErrorMessage = '',
    String? copySuccessMessage,
    Future<void> Function()? onDelete,
    String deleteErrorMessage = '',
    String? deleteSuccessMessage,
    Future<void> Function()? onSave,
    String saveErrorMessage = '',
    Future<void> Function()? onSetPrimary,
    String setPrimaryErrorMessage = '',
  }) async {
    switch (action) {
      case EntityContextMenuAction.copy:
        if (onCopy == null) return;
        final success = await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: onCopy,
          errorTitle: 'common.error'.tr(),
          errorMessage: copyErrorMessage,
        );
        if (success && context.mounted && copySuccessMessage != null) {
          AppSnackBar.showSuccess(context, copySuccessMessage);
        }
      case EntityContextMenuAction.delete:
        if (onDelete == null) return;
        final confirmed = await DialogHelpers.showDeleteConfirmation(
          context: context,
          itemType: entityTypeLabel,
          itemName: entityName,
        );
        if (confirmed && context.mounted) {
          final success = await ErrorRetryDialog.executeWithRetry(
            context: context,
            operation: onDelete,
            errorTitle: 'common.error'.tr(),
            errorMessage: deleteErrorMessage,
          );
          if (success && context.mounted && deleteSuccessMessage != null) {
            AppSnackBar.showSuccess(context, deleteSuccessMessage);
          }
        }
      case EntityContextMenuAction.save:
        if (onSave == null) return;
        await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: onSave,
          errorTitle: 'common.error'.tr(),
          errorMessage: saveErrorMessage,
        );
      case EntityContextMenuAction.setPrimary:
        if (onSetPrimary == null) return;
        await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: onSetPrimary,
          errorTitle: 'common.error'.tr(),
          errorMessage: setPrimaryErrorMessage,
        );
    }
  }
}
