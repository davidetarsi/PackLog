import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/ds_sheet_header.dart';
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
  return showModalBottomSheet(
    context: context,
    // Senza isScrollControlled il sheet è limitato a 9/16 dello schermo: con
    // la testata in più il contenuto non ci sta sugli schermi bassi.
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSheetHeader(title: 'houses.manage_sheet_title'.tr()),
            if (onSelectItems != null)
              ListTile(
                leading: const Icon(Icons.checklist),
                title: Text('items.select_items'.tr()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelectItems();
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('houses.edit_info'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                showAddEditHouseSheet(context, houseId: houseId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text('spaces.title'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                showHouseSpacesSheet(context, houseId: houseId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
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
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'common.delete'.tr(),
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
