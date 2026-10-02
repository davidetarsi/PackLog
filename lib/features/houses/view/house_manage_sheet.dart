import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../luggages/view/luggages_management_screen.dart';
import '../../spaces/view/spaces_management_screen.dart';
import 'add_edit_house_screen.dart';

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
}) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text('houses.edit_info'.tr()),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddEditHouseSheet(context, houseId: houseId);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.push_pin,
              color: isPrimary
                  ? null
                  : Theme.of(sheetContext).colorScheme.primary,
            ),
            title: Text('houses.set_as_primary'.tr()),
            enabled: !isPrimary,
            onTap: isPrimary
                ? null
                : () {
                    Navigator.pop(sheetContext);
                    onSetPrimary();
                  },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.meeting_room),
            title: Text('spaces.manage'.tr()),
            onTap: () async {
              Navigator.pop(sheetContext);
              await showSpacesManagementSheet(context, houseId: houseId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.luggage),
            title: Text('luggages.manage'.tr()),
            onTap: () async {
              Navigator.pop(sheetContext);
              await showLuggagesManagementSheet(context, houseId: houseId);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            title: Text(
              'common.delete'.tr(),
              style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onDelete();
            },
          ),
        ],
      ),
    ),
  );
}
