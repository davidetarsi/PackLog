import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/ds_badge.dart';
import '../../../../shared/widgets/ds_icon_button.dart';
import '../../../../shared/widgets/ds_settings.dart';
import '../../../../shared/widgets/quantity_stepper.dart';
import '../../repositories/kit_repository.dart';

/// Una riga del kit: nome, copie e, se serve, lo spazio dove sta l'oggetto in
/// casa. Con [onRemove] c'è la X che lo toglie dal kit (non dalla casa); con
/// [onCopiesChanged] le copie si cambiano con lo stepper invece del badge.
class KitItemRow extends StatelessWidget {
  const KitItemRow({
    super.key,
    required this.name,
    required this.copies,
    this.spaceName,
    this.onRemove,
    this.onCopiesChanged,
    this.removeKey,
  });

  final String name;
  final int copies;
  final String? spaceName;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onCopiesChanged;
  final Key? removeKey;

  @override
  Widget build(BuildContext context) {
    return DsSettingsRow(
      label: name,
      subtitle: spaceName,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCopiesChanged != null)
            QuantityStepper(
              value: copies,
              maxValue: kMaxCopiesPerItem,
              onChanged: onCopiesChanged!,
            )
          else
            DsQuantityBadge(current: copies),
          if (onRemove != null)
            DsIconButton(
              key: removeKey,
              icon: Icons.close,
              tooltip: 'kits.remove_item'.tr(),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
