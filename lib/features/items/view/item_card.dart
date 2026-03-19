import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stuff_tracker_2/features/items/view/item_category.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/dialog_helpers.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    
    final totalQuantity = item.quantity ?? 1;
    final availableQuantity = totalQuantity - quantityOnTrip;
    final isFullyOnTrip = quantityOnTrip > 0 && availableQuantity == 0;
    final hasAnyOnTrip = quantityOnTrip > 0;

    // Costruisci subtitle dinamico
    Widget? subtitle;
    if (hasAnyOnTrip) {
      // Mostra stato transito con color-coding
      if (isFullyOnTrip) {
        // Item completamente in viaggio: tutto in primary
        subtitle = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 12,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'common.in_transit'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      } else {
        // Partial transit: parte qui (grigio), parte in viaggio (primary)
        subtitle = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$availableQuantity ${'common.here'.tr()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ' • ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(
              Icons.flight_takeoff,
              size: 12,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '$quantityOnTrip ${'common.in_transit'.tr().toLowerCase()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }
    } else if (item.description != null) {
      // Mostra descrizione se non in transito
      subtitle = Text(
        item.description!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return UniversalItemTile(
      onTap: isFullyOnTrip ? null : () => _onEdit(context),
      onLongPress: hasAnyOnTrip ? null : () => _onDelete(context, ref),
      leading: CategoryIcon(category: item.category),
      title: Text(
        item.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle,
      trailing: Text(
        'x$totalQuantity',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
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

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
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