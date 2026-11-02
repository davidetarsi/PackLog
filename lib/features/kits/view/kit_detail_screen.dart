import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/widgets/ds_icon_button.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../model/kit_model.dart';
import '../providers/kit_provider.dart';
import 'kit_to_trip.dart';
import 'widgets/kit_detail_actions.dart';
import 'widgets/kit_detail_body.dart';

/// Il kit aperto: pillole d'uso, oggetti, "Aggiungi oggetti" e "Metti in
/// valigia…", più modifica e cancellazione (che lascia gli oggetti in casa).
class KitDetailScreen extends ConsumerWidget {
  const KitDetailScreen({
    super.key,
    required this.houseId,
    required this.kitId,
  });

  final String houseId;
  final String kitId;

  String get _base => '/houses/$houseId/kits/$kitId';

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    KitModel kit,
  ) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: '',
      itemName: kit.name,
      customTitle: 'kits.delete'.tr(),
      warningText: 'kits.delete_warning'.tr(),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(kitNotifierProvider(houseId).notifier).deleteKit(kit.id);
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'errors.delete_error'.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref
        .watch(kitNotifierProvider(houseId))
        .valueOrNull
        ?.where((k) => k.id == kitId)
        .firstOrNull;

    if (kit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ref.watch(kitNotifierProvider(houseId)).isLoading
            ? const SizedBox.shrink()
            : DsNotFoundState(
                icon: Icons.inventory_2_outlined,
                title: 'kits.not_found'.tr(),
                actionLabel: 'common.close'.tr(),
                onAction: () => context.pop(),
              ),
      );
    }

    return StickyCtaScaffold(
      appBar: AppBar(
        title: Text(kit.name),
        actions: [
          DsIconButton(
            key: const Key('kit_edit'),
            icon: Icons.edit_outlined,
            tooltip: 'common.edit'.tr(),
            onPressed: () => context.push('$_base/edit'),
          ),
          DsIconButton(
            key: const Key('kit_delete'),
            icon: Icons.delete_outline,
            tooltip: 'kits.delete'.tr(),
            onPressed: () => _delete(context, ref, kit),
          ),
        ],
      ),
      body: KitDetailBody(kit: kit),
      bottomContent: KitDetailActions(
        onAddItems: () => context.push('$_base/edit?add=1'),
        onPutInTrip: () => putKitInTrip(context, ref, kit),
      ),
    );
  }
}
