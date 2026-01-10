import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/model/trip_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';

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
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.inventory_2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Oggetti in $houseName',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              final hasTemporaryItems = temporaryItems.isNotEmpty;

              if (items.isEmpty && !hasTemporaryItems) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: AppColors.disabled,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Nessun oggetto',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.disabled,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aggiungi il tuo primo oggetto',
                        style: TextStyle(
                          fontSize: 14,
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
                padding: const EdgeInsets.all(16),
                children: [
                  // Sezione items temporanei (da viaggi attivi)
                  if (hasTemporaryItems) ...[
                    _buildTemporaryItemsSection(context, temporaryItems),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  // Items normali raggruppati per categoria
                  ...itemsByCategory.entries.map((entry) {
                    final category = entry.key;
                    final categoryItems = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
                        const SizedBox(height: 16),
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
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(height: 16),
                  Text('Errore: $error'),
                  const SizedBox(height: 16),
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
            Icon(Icons.luggage, color: AppColors.itemTemporary),
            const SizedBox(width: 8),
            Text(
              'Oggetti temporanei (in arrivo)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.itemTemporary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildTemporaryItemCard(context, item)),
      ],
    );
  }

  Widget _buildTemporaryItemCard(BuildContext context, TripItem item) {
    final appColors = context.appColors;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: appColors.itemTemporaryBackground,
      child: ListTile(
        leading: Stack(
          children: [
            Icon(Icons.inventory_2, color: appColors.itemTemporary),
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
      margin: const EdgeInsets.only(bottom: 8),
      color: isFullyOnTrip ? appColors.itemOnTripBackground : null,
      child: ListTile(
        onTap: isFullyOnTrip
            ? null
            : () {
                context.push('/houses/$houseId/items/${item.id}/edit');
              },
        leading: Stack(
          children: [
            _getCategoryIcon(item.category),
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
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            // Bottone elimina
            IconButton(
              icon: Icon(
                Icons.delete,
                color: hasAnyOnTrip
                    ? AppColors.disabled
                    : AppColors.destructive,
              ),
              onPressed: hasAnyOnTrip
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Elimina oggetto'),
                          content: Text(
                            'Sei sicuro di voler eliminare "${item.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => context.pop(false),
                              child: const Text('Annulla'),
                            ),
                            TextButton(
                              onPressed: () => context.pop(true),
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

  Widget _getCategoryIcon(ItemCategory category) {
    switch (category) {
      case ItemCategory.vestiti:
        return const Icon(Icons.checkroom);
      case ItemCategory.toiletries:
        return const Icon(Icons.spa);
      case ItemCategory.elettronica:
        return const Icon(Icons.devices);
      case ItemCategory.varie:
        return const Icon(Icons.category);
    }
  }
}
