import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/model/trip_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import 'add_edit_item_screen.dart';

class ItemsScreen extends ConsumerWidget {
  final String houseId;
  final String houseName;

  const ItemsScreen({
    super.key,
    required this.houseId,
    required this.houseName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemNotifierProvider(houseId));
    final itemQuantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(houseId),
    );
    final temporaryItems = ref.watch(temporaryItemsInHouseProvider(houseId));

    return Column(
      children: [
        // Container(
        //   padding: const EdgeInsets.all(16),
        //   color: Theme.of(context).colorScheme.surfaceContainerHighest,
        //   child: Row(
        //     children: [
        //       const Icon(Icons.inventory_2),
        //       const SizedBox(width: 8),
        //       Expanded(
        //         child: Text(
        //           'Oggetti in $houseName',
        //           style: Theme.of(context).textTheme.titleLarge,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              final hasTemporaryItems = temporaryItems.isNotEmpty;

              if (items.isEmpty && !hasTemporaryItems) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: context.iconSizeHero,
                        color: AppColors.disabled,
                      ),
                      SizedBox(height: context.spacingMd),
                      Text(
                        'Nessun oggetto',
                        style: TextStyle(
                          fontSize: context.fontSizeXl,
                          color: AppColors.disabled,
                        ),
                      ),
                      SizedBox(height: context.spacingSm),
                      Text(
                        'Aggiungi il tuo primo oggetto',
                        style: TextStyle(
                          fontSize: context.fontSizeMd,
                          color: AppColors.disabled,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Raggruppa per categoria
              final itemsByCategory = <ItemCategory, List<ItemModel>>{};
              for (final item in items) {
                itemsByCategory.putIfAbsent(item.category, () => []).add(item);
              }

              return ListView(
                padding: context.responsiveScreenPadding,
                children: [
                  // Sezione items temporanei (da viaggi attivi)
                  if (hasTemporaryItems) ...[
                    _buildTemporaryItemsSection(context, temporaryItems),
                    SizedBox(height: context.spacingLg),
                    const Divider(),
                    SizedBox(height: context.spacingMd),
                  ],

                  // Items normali raggruppati per categoria
                  ...itemsByCategory.entries.map((entry) {
                    final category = entry.key;
                    final categoryItems = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: context.spacingSm),
                          child: Text(
                            category.displayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...categoryItems.map((item) {
                          final quantityOnTrip =
                              itemQuantitiesOnTrip[item.id] ?? 0;
                          return _buildItemCard(
                            context,
                            ref,
                            item,
                            quantityOnTrip,
                          );
                        }),
                        SizedBox(height: context.spacingMd),
                      ],
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: context.iconSizeHero,
                    color: AppColors.destructive,
                  ),
                  SizedBox(height: context.spacingMd),
                  Text('Errore: $error'),
                  SizedBox(height: context.spacingMd),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(itemNotifierProvider(houseId).notifier)
                          .refresh(houseId);
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemporaryItemsSection(
    BuildContext context,
    List<TripItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.luggage,
              color: AppColors.itemTemporary,
              size: context.iconSizeMd,
            ),
            SizedBox(width: context.spacingSm),
            Text(
              'Oggetti temporanei (in arrivo)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.itemTemporary,
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacingSm),
        ...items.map((item) => _buildTemporaryItemCard(context, item)),
      ],
    );
  }

  Widget _buildTemporaryItemCard(BuildContext context, TripItem item) {
    final appColors = context.appColors;

    return Card(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      color: appColors.itemTemporaryBackground,
      child: ListTile(
        leading: Stack(
          children: [
            Icon(
              Icons.inventory_2,
              color: appColors.itemTemporary,
              size: context.iconSizeMd,
            ),
            StatusIconOverlay.temporary(),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(color: appColors.itemTemporaryText),
              ),
            ),
            const TemporaryBadge(),
          ],
        ),
        subtitle: Text(
          item.category,
          style: TextStyle(color: appColors.itemTemporary),
        ),
        trailing: Text(
          'x${item.quantity}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: appColors.itemTemporaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    WidgetRef ref,
    ItemModel item,
    int quantityOnTrip,
  ) {
    final appColors = context.appColors;
    final colorScheme = Theme.of(context).colorScheme;
    final totalQuantity = item.quantity ?? 1;
    final availableQuantity = totalQuantity - quantityOnTrip;
    final isPartiallyOnTrip = quantityOnTrip > 0 && availableQuantity > 0;
    final isFullyOnTrip = quantityOnTrip > 0 && availableQuantity == 0;
    final hasAnyOnTrip = quantityOnTrip > 0;

    return Card(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      color: isFullyOnTrip ? appColors.itemOnTripBackground : null,
      child: ListTile(
        onTap: isFullyOnTrip
            ? null
            : () {
                showAddEditItemSheet(
                  context,
                  houseId: houseId,
                  itemId: item.id,
                );
              },
        leading: Stack(
          children: [
            _getCategoryIcon(context, item.category),
            if (hasAnyOnTrip) StatusIconOverlay.onTrip(),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: isFullyOnTrip
                    ? TextStyle(color: appColors.itemOnTripText)
                    : null,
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
                style: isFullyOnTrip
                    ? TextStyle(color: appColors.itemOnTrip)
                    : null,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quantità
            Text(
              isPartiallyOnTrip
                  ? 'x$availableQuantity/$totalQuantity'
                  : 'x$totalQuantity',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFullyOnTrip
                    ? appColors.itemOnTrip
                    : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(width: context.spacingSm),
            // Bottone elimina
            IconButton(
              icon: Icon(
                Icons.delete,
                color: hasAnyOnTrip
                    ? AppColors.disabled
                    : AppColors.destructive,
                size: context.iconSizeMd,
              ),
              onPressed: hasAnyOnTrip
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Elimina oggetto'),
                          content: Text(
                            'Sei sicuro di voler eliminare "${item.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => dialogContext.pop(false),
                              child: const Text('Annulla'),
                            ),
                            TextButton(
                              onPressed: () => dialogContext.pop(true),
                              child: const Text(
                                'Elimina',
                                style: TextStyle(color: AppColors.destructive),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(itemNotifierProvider(houseId).notifier)
                            .deleteItem(item.id, houseId);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryIcon(BuildContext context, ItemCategory category) {
    final size = context.iconSizeMd;
    switch (category) {
      case ItemCategory.vestiti:
        return Icon(Icons.checkroom, size: size);
      case ItemCategory.toiletries:
        return Icon(Icons.spa, size: size);
      case ItemCategory.elettronica:
        return Icon(Icons.devices, size: size);
      case ItemCategory.varie:
        return Icon(Icons.category, size: size);
    }
  }
}
