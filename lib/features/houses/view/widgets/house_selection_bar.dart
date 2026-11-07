import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/ds_floating_bar.dart';

/// Barra in basso della selezione multipla: Sposta, Kit, In viaggio, Elimina.
/// Le azioni sono attive solo con almeno un oggetto selezionato; le esegue lo
/// schermo (le callback), così sopravvivono alla barra.
class HouseSelectionBar extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onMove;
  final VoidCallback onKit;
  final VoidCallback onTrip;
  final VoidCallback onDelete;

  const HouseSelectionBar({
    super.key,
    required this.hasSelection,
    required this.onMove,
    required this.onKit,
    required this.onTrip,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DsFloatingBar(
      children: [
        DsBarItem(
          key: const Key('selection_move'),
          icon: Icons.drive_file_move_outline,
          label: 'common.move'.tr(),
          onTap: hasSelection ? onMove : null,
        ),
        DsBarItem(
          key: const Key('selection_kit'),
          icon: Icons.inventory_2_outlined,
          label: 'kits.to_kit'.tr(),
          onTap: hasSelection ? onKit : null,
        ),
        DsBarItem(
          key: const Key('selection_trip'),
          icon: Icons.luggage_outlined,
          label: 'items.to_trip'.tr(),
          onTap: hasSelection ? onTrip : null,
        ),
        DsBarItem(
          key: const Key('selection_delete'),
          icon: Icons.delete_outline,
          label: 'common.delete'.tr(),
          onTap: hasSelection ? onDelete : null,
        ),
      ],
    );
  }
}
