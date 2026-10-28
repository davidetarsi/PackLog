import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import 'ds_form_sheet.dart';
import 'ds_settings.dart';

enum EntityContextMenuAction { copy, save, setPrimary, delete }

/// Foglio della pressione lunga su una casa o un viaggio. Ogni voce chiude il
/// foglio e restituisce la sua azione; la x e il tasto indietro restituiscono
/// null. [title] è il nome dell'entità, [entityType] il tipo per le etichette.
Future<EntityContextMenuAction?> showEntityContextMenu({
  required BuildContext context,
  required String entityType,
  String? title,
  bool showSaveAction = false,
  bool isSaved = false,
  bool showSetPrimaryAction = false,
  bool isPrimary = false,
}) {
  HapticFeedback.mediumImpact();

  return showDsSheet<EntityContextMenuAction>(
    context,
    builder: (sheetContext) => DsFormSheet(
      title: title ?? entityType,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSettingsGroup(
            children: [
              DsSettingsRow(
                leading: const Icon(Icons.copy_rounded),
                label: 'dialogs.context_menu_copy'.tr(args: [entityType]),
                onTap: () =>
                    Navigator.pop(sheetContext, EntityContextMenuAction.copy),
              ),
              if (showSaveAction)
                DsSettingsRow(
                  leading: Icon(
                    isSaved
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                  ),
                  label: isSaved
                      ? 'dialogs.context_menu_unsave'.tr(args: [entityType])
                      : 'dialogs.context_menu_save'.tr(args: [entityType]),
                  onTap: () =>
                      Navigator.pop(sheetContext, EntityContextMenuAction.save),
                ),
              if (showSetPrimaryAction)
                DsSettingsRow(
                  leading: const Icon(Icons.star_outline_rounded),
                  label: 'dialogs.context_menu_set_primary'.tr(),
                  enabled: !isPrimary,
                  onTap: () => Navigator.pop(
                    sheetContext,
                    EntityContextMenuAction.setPrimary,
                  ),
                ),
            ],
          ),
          SizedBox(height: sheetContext.spacingMd),
          DsSettingsGroup(
            children: [
              DsSettingsRow(
                leading: const Icon(Icons.delete_outline_rounded),
                label: 'dialogs.context_menu_delete'.tr(args: [entityType]),
                destructive: true,
                onTap: () =>
                    Navigator.pop(sheetContext, EntityContextMenuAction.delete),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
