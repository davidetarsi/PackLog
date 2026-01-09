import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/model/trip_model.dart';

class ItemsScreen extends ConsumerWidget {
  final String houseId;
  final String houseName;

  const ItemsScreen({super.key, required this.houseId, required this.houseName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemNotifierProvider(houseId));
    final itemsOnTrip = ref.watch(itemsOnTripFromHouseProvider(houseId));
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
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nessun oggetto',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aggiungi il tuo primo oggetto',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...categoryItems.map((item) {
                          final isOnTrip = itemsOnTrip.contains(item.id);
                          return _buildItemCard(context, ref, item, isOnTrip);
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Errore: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(itemNotifierProvider(houseId).notifier).refresh(houseId);
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

  Widget _buildTemporaryItemsSection(BuildContext context, List<TripItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.luggage, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'Oggetti temporanei (in arrivo)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.blue.shade50,
      child: ListTile(
        leading: Stack(
          children: [
            Icon(Icons.inventory_2, color: Colors.blue.shade600),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flight_land, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(color: Colors.blue.shade800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Temporaneo',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${item.category} • Quantità: ${item.quantity}',
          style: TextStyle(color: Colors.blue.shade600),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, ItemModel item, bool isOnTrip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isOnTrip ? Colors.orange.shade50 : null,
      child: ListTile(
        leading: Stack(
          children: [
            _getCategoryIcon(item.category),
            if (isOnTrip)
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.luggage, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: isOnTrip
                    ? TextStyle(color: Colors.orange.shade800)
                    : null,
              ),
            ),
            if (isOnTrip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'In viaggio',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: item.description != null
            ? Text(
                item.description!,
                style: isOnTrip
                    ? TextStyle(color: Colors.orange.shade600)
                    : null,
              )
            : item.quantity != null
                ? Text(
                    'Quantità: ${item.quantity}',
                    style: isOnTrip
                        ? TextStyle(color: Colors.orange.shade600)
                        : null,
                  )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit,
                color: isOnTrip ? Colors.orange.shade400 : null,
              ),
              onPressed: isOnTrip
                  ? null
                  : () {
                      context.push('/houses/$houseId/items/${item.id}/edit');
                    },
            ),
            IconButton(
              icon: Icon(
                Icons.delete,
                color: isOnTrip ? Colors.grey : Colors.red,
              ),
              onPressed: isOnTrip
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Elimina oggetto'),
                          content: Text('Sei sicuro di voler eliminare "${item.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => context.pop(false),
                              child: const Text('Annulla'),
                            ),
                            TextButton(
                              onPressed: () => context.pop(true),
                              child: const Text('Elimina', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(itemNotifierProvider(houseId).notifier).deleteItem(item.id, houseId);
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

