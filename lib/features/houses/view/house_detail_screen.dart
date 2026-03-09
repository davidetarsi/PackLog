import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import '../../spaces/view/spaces_management_screen.dart';
import '../../luggages/view/luggages_management_screen.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/helpers/design_system.dart';

class HouseDetailScreen extends ConsumerWidget {
  final String houseId;

  const HouseDetailScreen({super.key, required this.houseId});

  Future<void> _setPrimary(BuildContext context, WidgetRef ref, String houseName) async {
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
                    case 'manage_spaces':
                      await showSpacesManagementSheet(context, houseId: houseId);
                      break;
                    case 'manage_luggages':
                      await showLuggagesManagementSheet(context, houseId: houseId);
                      break;
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
                  PopupMenuItem(
                    value: 'manage_spaces',
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room),
                        const SizedBox(width: 12),
                        Text('spaces.manage'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'manage_luggages',
                    child: Row(
                      children: [
                        const Icon(Icons.luggage),
                        const SizedBox(width: 12),
                        Text('luggages.manage'.tr()),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: 12),
                        Text('common.edit'.tr()),
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
                          'houses.set_as_primary'.tr(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete),
                        const SizedBox(width: 12),
                        Text('common.delete'.tr()),
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
        appBar: AppBar(title: Text('common.error'.tr())),
        body: ErrorState(
          error: error,
          onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
