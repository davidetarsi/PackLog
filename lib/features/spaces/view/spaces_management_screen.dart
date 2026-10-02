import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/space_model.dart';
import '../providers/space_provider.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/widgets/entity_management_sheet.dart';
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

/// Bottom sheet per gestire gli spazi di una casa.
///
/// Delega il layout generico a [EntityManagementSheet]; gestisce qui
/// le operazioni specifiche degli spazi: edit (invalida anche gli items),
/// delete con pre-check numero item contenuti, e aggiunta.
class SpacesManagementSheet extends StatelessWidget {
  final String houseId;

  const SpacesManagementSheet({super.key, required this.houseId});

  Future<void> _onEdit(
    BuildContext context,
    WidgetRef ref,
    SpaceModel space,
  ) async {
    await showAddEditSpaceSheet(context, houseId: houseId, spaceId: space.id);
    if (context.mounted) {
      ref.invalidate(spaceNotifierProvider(houseId));
      ref.invalidate(itemNotifierProvider(houseId));
    }
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    SpaceModel space,
  ) async {
    final itemCount = await ref
        .read(itemRepositoryProvider)
        .countItemsBySpace(space.id);
    if (!context.mounted) return;

    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: '',
      itemName: space.name,
      customTitle: 'spaces.delete'.tr(),
      warningText: itemCount > 0 ? 'spaces.delete_warning'.tr() : null,
    );
    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          await ref
              .read(spaceNotifierProvider(houseId).notifier)
              .deleteSpace(space.id);
        },
        errorTitle: 'common.error'.tr(),
        errorMessage: 'errors.delete_space_failed'.tr(args: [space.name]),
      );
      if (success && context.mounted) {
        // SpaceNotifier(houseId) si auto-aggiorna dopo deleteSpace; serve
        // invalidare solo gli items, dato che potrebbero referenziare lo
        // space appena cancellato (FK SET NULL).
        ref.invalidate(itemNotifierProvider(houseId));
        AppSnackBar.showSuccess(
          context,
          'spaces.space_deleted'.tr(args: [space.name]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EntityManagementSheet<SpaceModel>(
      title: 'spaces.title'.tr(),
      watch: (ref) => ref.watch(spaceNotifierProvider(houseId)),
      getIcon: (s) => s.iconName != null
          ? SpaceIcons.getIcon(s.iconName!)
          : Icons.meeting_room,
      getName: (s) => s.name,
      onEdit: _onEdit,
      onDelete: _onDelete,
      onRetry: (ref) => ref.invalidate(spaceNotifierProvider(houseId)),
      addLabel: 'spaces.add_new'.tr(),
      onAdd: (context, ref) async {
        await showAddEditSpaceSheet(context, houseId: houseId);
        if (context.mounted) {
          ref.invalidate(itemNotifierProvider(houseId));
        }
      },
      emptyIcon: Icons.meeting_room_outlined,
      emptyTitle: 'spaces.no_spaces'.tr(),
      emptySubtitle: 'spaces.no_spaces_subtitle'.tr(),
    );
  }
}
