import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/helpers/design_system.dart';
import '../../../../shared/helpers/snack_bar_helper.dart';
import '../../../../shared/widgets/error_retry_dialog.dart';
import '../../../items/providers/item_provider.dart';
import '../../providers/house_provider.dart';
import '../../../trips/providers/trip_items_status_provider.dart';

// Azioni sulla casa (principale, eliminazione) lanciate dal foglio di gestione.

Future<void> setPrimaryHouse(
  BuildContext context,
  WidgetRef ref,
  String houseId,
  String houseName,
) async {
  final success = await ErrorRetryDialog.executeWithRetry(
    context: context,
    operation: () async {
      await ref.read(houseNotifierProvider.notifier).setPrimaryHouse(houseId);
    },
    errorTitle: 'common.error'.tr(),
    errorMessage: 'errors.set_primary_failed'.tr(args: [houseName]),
  );

  if (success && context.mounted) {
    AppSnackBar.showSuccess(
      context,
      'houses.primary_house_set'.tr(args: [houseName]),
    );
  }
}

Future<void> showDeleteHouseDialog(
  BuildContext context,
  WidgetRef ref,
  String houseId,
  String houseName,
) async {
  final itemsAsync = ref.read(itemNotifierProvider(houseId));
  final temporaryItems = ref.read(temporaryItemsInHouseProvider(houseId));

  final permanentItemsCount = itemsAsync.value?.length ?? 0;
  final temporaryItemsCount = temporaryItems.length;
  final totalItemsCount = permanentItemsCount + temporaryItemsCount;

  if (totalItemsCount > 0) {
    if (!context.mounted) return;

    await DialogHelpers.showInfo(
      context: context,
      title: 'common.error'.tr(),
      message: 'houses.cannot_delete_has_items'.tr(),
      details: [
        if (permanentItemsCount > 0)
          'houses.permanent_items_count'.tr(
            args: [permanentItemsCount.toString()],
          ),
        if (temporaryItemsCount > 0)
          'houses.temporary_items_count'.tr(
            args: [temporaryItemsCount.toString()],
          ),
      ],
    );
    return;
  }

  final confirmed = await DialogHelpers.showDeleteConfirmation(
    context: context,
    itemType: 'common.house_type'.tr(),
    itemName: houseName,
  );

  if (confirmed == true && context.mounted) {
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        await ref.read(houseNotifierProvider.notifier).deleteHouse(houseId);
      },
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.delete_failed'.tr(args: [houseName]),
    );

    if (success && context.mounted) {
      context.go('/');
    }
  }
}
