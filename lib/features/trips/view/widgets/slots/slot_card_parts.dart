import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../model/ai_packing.dart';

// I pezzi che la card di un importante e la riga "da comprare" hanno in
// comune.

/// Etichetta "Importante" con la bandierina, nel colore [color].
class ImportantLabel extends StatelessWidget {
  const ImportantLabel({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag_outlined, size: context.iconSizeXs, color: color),
        SizedBox(width: context.spacingXs),
        Flexible(
          child: Text(
            'trips.slots.important'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelLarge?.regular.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// La X che toglie un importante (chi la usa chiede conferma).
class RemoveSlotButton extends StatelessWidget {
  const RemoveSlotButton({
    super.key,
    required this.slot,
    required this.onPressed,
  });

  final AiSlot slot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DsIconButton(
      key: Key('slot_remove_${slot.id}'),
      icon: Icons.close,
      tooltip: 'trips.slots.remove_confirm'.tr(),
      onPressed: onPressed,
    );
  }
}
