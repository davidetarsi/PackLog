import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_settings.dart';
import 'add_edit_house_screen.dart';
import 'house_spaces_sheet.dart';

/// Shows the "manage house" bottom sheet.
///
/// Business logic (delete, set primary) is delegated via callbacks so this
/// widget stays free of Riverpod dependencies.
Future<void> showHouseManageSheet(
  BuildContext context, {
  required String houseId,
  required bool isPrimary,
  required String houseName,
  required VoidCallback onSetPrimary,
  required VoidCallback onDelete,
  VoidCallback? onSelectItems,
}) {
  return showDsSheet<void>(
    context,
    builder: (sheetContext) => DsFormSheet(
      title: 'houses.manage_sheet_title'.tr(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSettingsGroup(
            children: [
              if (onSelectItems != null)
                DsSettingsRow(
                  leading: const Icon(Icons.checklist),
                  label: 'items.select_items'.tr(),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelectItems();
                  },
                ),
              DsSettingsRow(
                leading: const Icon(Icons.edit),
                label: 'houses.edit_info'.tr(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showAddEditHouseSheet(context, houseId: houseId);
                },
              ),
              DsSettingsRow(
                leading: const Icon(Icons.meeting_room_outlined),
                label: 'spaces.title'.tr(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showHouseSpacesSheet(context, houseId: houseId);
                },
              ),
              DsSettingsRow(
                leading: const Icon(Icons.push_pin_outlined),
                label: 'houses.set_as_primary'.tr(),
                enabled: !isPrimary,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSetPrimary();
                },
              ),
            ],
          ),
          SizedBox(height: context.spacingMd),
          DsSettingsGroup(
            children: [
              DsSettingsRow(
                leading: const Icon(Icons.delete_outline),
                label: 'common.delete'.tr(),
                destructive: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
