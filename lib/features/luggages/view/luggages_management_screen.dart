import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/luggage_model.dart';
import '../providers/luggage_provider.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/widgets/entity_management_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import 'add_edit_luggage_screen.dart';

/// Mostra il bottom sheet per gestire i bagagli di una casa
Future<void> showLuggagesManagementSheet(
  BuildContext context, {
  required String houseId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LuggagesManagementSheet(houseId: houseId),
  );
}

/// Bottom sheet per gestire i bagagli di una casa.
///
/// Delega il layout generico a [EntityManagementSheet]; gestisce qui
/// le operazioni specifiche dei bagagli: edit, delete con conferma,
/// e aggiunta.
class LuggagesManagementSheet extends StatelessWidget {
  final String houseId;

  const LuggagesManagementSheet({super.key, required this.houseId});

  Future<void> _onEdit(
    BuildContext context,
    WidgetRef ref,
    LuggageModel luggage,
  ) async {
    await showAddEditLuggageSheet(
      context,
      houseId: houseId,
      luggageId: luggage.id,
    );
    if (context.mounted) {
      ref.invalidate(luggageNotifierProvider(houseId));
    }
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    LuggageModel luggage,
  ) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: '',
      itemName: luggage.name,
      customTitle: 'luggages.delete'.tr(),
      warningText: 'luggages.delete_warning'.tr(),
    );
    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          await ref
              .read(luggageNotifierProvider(houseId).notifier)
              .deleteLuggage(luggage.id);
        },
        errorTitle: 'common.error'.tr(),
        errorMessage: 'errors.delete_luggage_failed'.tr(args: [luggage.name]),
      );
      if (success && context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'luggages.luggage_deleted'.tr(args: [luggage.name]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EntityManagementSheet<LuggageModel>(
      title: 'luggages.title'.tr(),
      watch: (ref) => ref.watch(luggageNotifierProvider(houseId)),
      getIcon: (_) => Icons.luggage,
      getName: (l) => l.name,
      getSubtitle: (l) => l.sizeDescription,
      onEdit: _onEdit,
      onDelete: _onDelete,
      onRetry: (ref) => ref.invalidate(luggageNotifierProvider(houseId)),
      addLabel: 'luggages.add_new'.tr(),
      onAdd: (context, ref) =>
          showAddEditLuggageSheet(context, houseId: houseId),
      emptyIcon: Icons.luggage_outlined,
      emptyTitle: 'luggages.no_luggages'.tr(),
      emptySubtitle: 'luggages.no_luggages_subtitle'.tr(),
    );
  }
}
