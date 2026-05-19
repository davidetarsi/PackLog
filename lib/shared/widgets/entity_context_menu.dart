import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

enum EntityContextMenuAction { copy, save, setPrimary, delete }

Future<EntityContextMenuAction?> showEntityContextMenu({
  required BuildContext context,
  required String entityType,
  bool showSaveAction = false,
  bool isSaved = false,
  bool showSetPrimaryAction = false,
  bool isPrimary = false,
}) {
  HapticFeedback.mediumImpact();

  return showDialog<EntityContextMenuAction>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;

      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppConstants.cardBorderRadius + 4,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.copy_rounded, color: colorScheme.primary),
                title: Text(
                  'dialogs.context_menu_copy'.tr(args: [entityType]),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                onTap: () =>
                    Navigator.pop(dialogContext, EntityContextMenuAction.copy),
              ),
              if (showSaveAction) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant,
                ),
                ListTile(
                  leading: Icon(
                    isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    isSaved
                        ? 'dialogs.context_menu_unsave'.tr(args: [entityType])
                        : 'dialogs.context_menu_save'.tr(args: [entityType]),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  onTap: () =>
                      Navigator.pop(dialogContext, EntityContextMenuAction.save),
                ),
              ],
              if (showSetPrimaryAction && !isPrimary) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant,
                ),
                ListTile(
                  leading: Icon(Icons.star_outline_rounded, color: colorScheme.primary),
                  title: Text(
                    'dialogs.context_menu_set_primary'.tr(),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  onTap: () => Navigator.pop(dialogContext, EntityContextMenuAction.setPrimary),
                ),
              ],
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  'dialogs.context_menu_delete'.tr(args: [entityType]),
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () => Navigator.pop(
                  dialogContext,
                  EntityContextMenuAction.delete,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
