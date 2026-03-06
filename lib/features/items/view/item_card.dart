import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stuff_tracker_2/features/items/view/item_category.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/helpers/design_system.dart';
import 'add_edit_item_screen.dart';

class ItemCard extends ConsumerWidget {
  final ItemModel item;
  final String houseId;
  final int quantityOnTrip;

  const ItemCard({
    super.key,
    required this.item,
    required this.houseId,
    required this.quantityOnTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = context.appColors;
    final colorScheme = Theme.of(context).colorScheme;
    
    final totalQuantity = item.quantity ?? 1;
    final availableQuantity = totalQuantity - quantityOnTrip;
    final isPartiallyOnTrip = quantityOnTrip > 0 && availableQuantity > 0;
    final isFullyOnTrip = quantityOnTrip > 0 && availableQuantity == 0;
    final hasAnyOnTrip = quantityOnTrip > 0;

    return Card(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      color: isFullyOnTrip ? appColors.itemOnTripBackground.withValues(alpha: 0.6) : null,
      child: ListTile(
        onTap: isFullyOnTrip ? null : () => _onEdit(context),
        leading: Stack(
          children: [
            CategoryIcon(category: item.category),
            //if (hasAnyOnTrip) StatusIconOverlay.onTrip(),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(fontSize: context.fontSizeSm),
                //style: isFullyOnTrip ? TextStyle(color: appColors.itemOnTripText) : null,
              ),
            ),
            if (isFullyOnTrip) const OnTripBadge(),
            if (isPartiallyOnTrip)
              OnTripQuantityBadge(
                quantity: quantityOnTrip,
                totalQuantity: totalQuantity,
              ),
          ],
        ),
        subtitle: item.description != null
            ? Text(
                item.description!,
                style: isFullyOnTrip ? TextStyle(color: appColors.itemOnTrip) : null,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPartiallyOnTrip ? 'x$availableQuantity/$totalQuantity' : 'x$totalQuantity',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                /* color: isFullyOnTrip
                    ? appColors.itemOnTripText
                    : colorScheme.onSurface.withValues(alpha: 0.7), */
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            _ItemPopupMenu(
              item: item,
              houseId: houseId,
              enabled: !hasAnyOnTrip,
              onEdit: () => _onEdit(context),
            ),
          ],
        ),
      ),
    );
  }

  void _onEdit(BuildContext context) {
    showAddEditItemSheet(
      context,
      houseId: houseId,
      itemId: item.id,
    );
  }
}

/// Menu azioni privato per ItemCard (Internal helper widget)
class _ItemPopupMenu extends ConsumerWidget {
  final ItemModel item;
  final String houseId;
  final bool enabled;
  final VoidCallback onEdit;

  const _ItemPopupMenu({
    required this.item,
    required this.houseId,
    required this.enabled,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: enabled ? Theme.of(context).colorScheme.onSurface : AppColors.disabled,
        size: context.iconSizeMd,
      ),
      enabled: enabled,
      onSelected: (value) async {
        if (value == 'edit') onEdit();
        if (value == 'delete') await _handleDelete(context, ref);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [const Icon(Icons.edit), const SizedBox(width: 12), Text('common.edit'.tr())]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete, color: AppColors.destructive),
            const SizedBox(width: 12),
            Text('common.delete'.tr(), style: const TextStyle(color: AppColors.destructive)),
          ]),
        ),
      ],
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.item_type'.tr(),
      itemName: item.name,
    );

    if (confirmed == true && context.mounted) {
      await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () => ref.read(itemNotifierProvider(houseId).notifier).deleteItem(item.id, houseId),
        errorTitle: 'common.error'.tr(),
        errorMessage: 'errors.delete_item_failed'.tr(args: [item.name]),
      );
    }
  }
}