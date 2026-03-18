import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import '../../items/view/add_edit_item_screen.dart';
import '../../items/providers/item_provider.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../spaces/view/spaces_management_screen.dart';
import '../../luggages/view/luggages_management_screen.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/helpers/design_system.dart';

class HouseDetailScreen extends ConsumerWidget {
  final String houseId;

  const HouseDetailScreen({super.key, required this.houseId});

  void _showManageSheet(BuildContext context, WidgetRef ref, String houseId, bool isPrimary, String houseName) {
    showModalBottomSheet(
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
                Icons.bookmark,
                color: isPrimary ? null : Theme.of(sheetContext).colorScheme.primary,
              ),
              title: Text('houses.set_as_primary'.tr()),
              enabled: !isPrimary,
              onTap: isPrimary
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      _setPrimaryHouse(context, ref, houseName);
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
          ],
        ),
      ),
    );
  }

  void _showAddItemsSheet(BuildContext context, String houseId) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text('houses.add_single_item'.tr()),
              onTap: () async {
                Navigator.pop(sheetContext);
                await showAddEditItemSheet(context, houseId: houseId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: Text('bulk_creation.add_from_template'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/bulk-creation/templates/$houseId');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrimaryHouse(BuildContext context, WidgetRef ref, String houseName) async {
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        await ref.read(houseNotifierProvider.notifier).setPrimaryHouse(houseId);
      },
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.set_primary_failed'.tr(args: [houseName]),
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('houses.primary_house_set'.tr(args: [houseName]))),
      );
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref, String houseName) async {
    // Verifica se ci sono oggetti nella casa (fissi o in viaggio)
    final itemsAsync = ref.read(itemNotifierProvider(houseId));
    final temporaryItems = ref.read(temporaryItemsInHouseProvider(houseId));
    
    final permanentItemsCount = itemsAsync.value?.length ?? 0;
    final temporaryItemsCount = temporaryItems.length;
    final totalItemsCount = permanentItemsCount + temporaryItemsCount;
    
    if (totalItemsCount > 0) {
      // Casa contiene oggetti: mostra errore e impedisci eliminazione
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text('common.error'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('houses.cannot_delete_has_items'.tr()),
                const SizedBox(height: 16),
                if (permanentItemsCount > 0)
                  Text(
                    '• ${'houses.permanent_items_count'.tr(args: [permanentItemsCount.toString()])}',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                if (temporaryItemsCount > 0)
                  Text(
                    '• ${'houses.temporary_items_count'.tr(args: [temporaryItemsCount.toString()])}',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('common.ok'.tr()),
              ),
            ],
          );
        },
      );
      return;
    }
    
    // Nessun oggetto: procedi con la conferma di eliminazione
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return housesAsync.when(
      data: (houses) {
        final matchingHouses = houses.where((h) => h.id == houseId);
        if (matchingHouses.isEmpty) {
          // Casa non trovata - mostra schermata di errore invece di reindirizzare
          return Scaffold(
            appBar: AppBar(title: Text('houses.house_not_found'.tr())),
            body: EmptyState(
              icon: Icons.home_outlined,
              title: 'houses.house_not_found_message'.tr(),
              action: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: Text('houses.back_to_houses'.tr()),
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
              onPressed: () => context.go('/'),
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
          ),
          body: ItemsScreen(houseId: houseId, houseName: house.name),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: context.spacingMd,
                right: context.spacingMd,
                top: context.spacingMd,
                bottom: context.spacingSm,
              ),
              child: UniversalActionBar(
                horizontalPadding: 0,
                primaryLabel: 'houses.manage'.tr(),
                primaryIcon: Icons.settings,
                onPrimaryPressed: () => _showManageSheet(context, ref, houseId, house.isPrimary, house.name),
                leftAction: CircularActionButton(
                  icon: Icons.delete_outline,
                  onPressed: () => _showDeleteDialog(context, ref, house.name),
                  color: colorScheme.error, // Icona rossa
                  showBorder: true,
                ),
                rightAction: CircularActionButton(
                  icon: Icons.add,
                  onPressed: () => _showAddItemsSheet(context, houseId),
                  showBorder: true,
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('common.error'.tr())),
        body: ErrorState(
          error: error,
          onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
