import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../theme/theme.dart';

enum EntityContextMenuAction { copy, delete }

Future<EntityContextMenuAction?> showEntityContextMenu({
  required BuildContext context,
  required String entityType,
}) {
  HapticFeedback.mediumImpact();

  return showDialog<EntityContextMenuAction>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;

      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius + 4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.copy_rounded,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'dialogs.context_menu_copy'.tr(args: [entityType]),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                onTap: () =>
                    Navigator.pop(dialogContext, EntityContextMenuAction.copy),
              ),
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
                onTap: () =>
                    Navigator.pop(dialogContext, EntityContextMenuAction.delete),
              ),
            ],
          ),
        ),
      );
    },
  );
}
