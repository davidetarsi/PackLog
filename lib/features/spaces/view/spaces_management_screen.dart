import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/space_model.dart';
import '../providers/space_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import 'add_edit_space_screen.dart';

/// Mostra il bottom sheet per gestire gli spazi di una casa
Future<void> showSpacesManagementSheet(
  BuildContext context, {
  required String houseId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SpacesManagementSheet(houseId: houseId),
  );
}

/// Bottom sheet per gestire gli spazi di una casa
class SpacesManagementSheet extends ConsumerWidget {
  final String houseId;

  const SpacesManagementSheet({super.key, required this.houseId});

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    SpaceModel space,
  ) async {
    final itemCount = await ref.read(itemRepositoryProvider).countItemsBySpace(space.id);
    
    if (!context.mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('spaces.delete'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('spaces.delete_confirmation'.tr(args: [space.name])),
            if (itemCount > 0) ...[
              SizedBox(height: dialogContext.spacingMd),
              Text(
                'spaces.delete_warning'.tr(),
                style: TextStyle(
                  fontSize: dialogContext.fontSizeSm,
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          await ref.read(spaceNotifierProvider.notifier).deleteSpace(space.id);
        },
        errorTitle: 'common.error'.tr(),
        errorMessage: 'errors.delete_space_failed'.tr(args: [space.name]),
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('spaces.space_deleted'.tr(args: [space.name]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacesAsync = ref.watch(spacesByHouseProvider(houseId));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.responsive(20)),
        ),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: context.responsiveScreenPadding,
            child: Row(
              children: [
                Text(
                  'spaces.title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: context.iconSizeMd),
                ),
              ],
            ),
          ),
          Expanded(
            child: spacesAsync.when(
              data: (spaces) {
                if (spaces.isEmpty) {
                  return EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'spaces.no_spaces'.tr(),
                    subtitle: 'spaces.no_spaces_subtitle'.tr(),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
                  itemCount: spaces.length,
                  itemBuilder: (context, index) {
                    final space = spaces[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: context.spacingSm),
                      elevation: 0,
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: context.responsiveBorderRadius(12),
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          space.iconName != null
                              ? HouseIcons.getIcon(space.iconName!)
                              : Icons.meeting_room,
                          color: colorScheme.primary,
                          size: context.iconSizeMd,
                        ),
                        title: Text(space.name),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            switch (value) {
                              case 'edit':
                                await showAddEditSpaceSheet(
                                  context,
                                  houseId: houseId,
                                  spaceId: space.id,
                                );
                                if (context.mounted) {
                                  ref.invalidate(spacesByHouseProvider(houseId));
                                }
                                break;
                              case 'delete':
                                await _showDeleteDialog(context, ref, space);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
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
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('common.error'.tr()),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await showAddEditSpaceSheet(context, houseId: houseId);
                  if (context.mounted) {
                    ref.invalidate(spacesByHouseProvider(houseId));
                  }
                },
                icon: const Icon(Icons.add),
                label: Text('spaces.add_new'.tr()),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
