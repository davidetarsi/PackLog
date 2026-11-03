import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_button.dart';

/// I due tasti in fondo al kit aperto: "Aggiungi oggetti" (secondario) e
/// "Metti in valigia…" (principale).
class KitDetailActions extends StatelessWidget {
  const KitDetailActions({
    super.key,
    required this.onAddItems,
    required this.onPutInTrip,
  });

  final VoidCallback onAddItems;
  final VoidCallback onPutInTrip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DsButton(
            label: 'kits.add_items'.tr(),
            variant: DsButtonVariant.neutral,
            onPressed: onAddItems,
          ),
        ),
        SizedBox(width: context.spacingSm),
        Expanded(
          child: DsButton(label: 'kits.to_trip'.tr(), onPressed: onPutInTrip),
        ),
      ],
    );
  }
}
