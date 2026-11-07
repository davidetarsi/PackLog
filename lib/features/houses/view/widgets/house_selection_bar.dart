import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/ds_floating_bar.dart';
import '../../../kits/view/add_selection_to_kit.dart';
import 'house_bulk_actions.dart';

/// Barra in basso della selezione multipla: Sposta, Kit, In viaggio, Elimina.
/// Le azioni sono attive solo con almeno un oggetto selezionato.
class HouseSelectionBar extends ConsumerWidget {
  final String houseId;
  final bool hasSelection;

  const HouseSelectionBar({
    super.key,
    required this.houseId,
    required this.hasSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DsFloatingBar(
      children: [
        DsBarItem(
          key: const Key('selection_move'),
          icon: Icons.drive_file_move_outline,
          label: 'common.move'.tr(),
          onTap: hasSelection
              ? () => handleBulkMove(context, ref, houseId)
              : null,
        ),
        DsBarItem(
          key: const Key('selection_kit'),
          icon: Icons.inventory_2_outlined,
          label: 'kits.to_kit'.tr(),
          onTap: hasSelection
              ? () => addSelectionToKit(context, ref, houseId: houseId)
              : null,
        ),
        DsBarItem(
          key: const Key('selection_trip'),
          icon: Icons.luggage_outlined,
          label: 'items.to_trip'.tr(),
          onTap: hasSelection
              ? () => handleAddToTrip(context, ref, houseId)
              : null,
        ),
        DsBarItem(
          key: const Key('selection_delete'),
          icon: Icons.delete_outline,
          label: 'common.delete'.tr(),
          onTap: hasSelection
              ? () => handleBulkDelete(context, ref, houseId)
              : null,
        ),
      ],
    );
  }
}
