import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/design_system/design_system.dart';

class HouseDetailScreen extends ConsumerWidget {
  final String houseId;

  const HouseDetailScreen({super.key, required this.houseId});

  Future<void> _setPrimary(BuildContext context, WidgetRef ref, String houseName) async {
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        await ref.read(houseNotifierProvider.notifier).setPrimaryHouse(houseId);
      },
      errorTitle: 'Errore',
      errorMessage: 'Impossibile impostare "$houseName" come casa principale.',
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$houseName" è ora la casa principale')),
      );
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref, String houseName) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'casa',
      itemName: houseName,
    );

    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          await ref.read(houseNotifierProvider.notifier).deleteHouse(houseId);
        },
        errorTitle: 'Errore',
        errorMessage: 'Impossibile eliminare "$houseName".',
      );

      if (success && context.mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return housesAsync.when(
      data: (houses) {
        final matchingHouses = houses.where((h) => h.id == houseId);
        if (matchingHouses.isEmpty) {
          // Casa non trovata - mostra schermata di errore invece di reindirizzare
          return Scaffold(
            appBar: AppBar(title: const Text('Casa non trovata')),
            body: EmptyState(
              icon: Icons.home_outlined,
              title: 'La casa richiesta non è stata trovata.',
              action: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Torna alla lista case'),
              ),
            ),
          );
        }
        final house = matchingHouses.first;
        final colorScheme = Theme.of(context).colorScheme;
        
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  HouseIcons.getIcon(house.iconName),
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(house.name),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      showAddEditHouseSheet(context, houseId: houseId);
                      break;
                    case 'set_primary':
                      await _setPrimary(context, ref, house.name);
                      break;
                    case 'delete':
                      await _showDeleteDialog(context, ref, house.name);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 12),
                        Text('Modifica'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'set_primary',
                    enabled: !house.isPrimary,
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_outlined,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Imposta come principale',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete,
                         ),
                        SizedBox(width: 12),
                        Text(
                          'Elimina',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ItemsScreen(houseId: houseId, houseName: house.name),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: ErrorState(
          error: error,
          onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
