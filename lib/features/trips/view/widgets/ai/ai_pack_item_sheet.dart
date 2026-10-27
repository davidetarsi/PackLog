import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../../shared/widgets/quantity_stepper.dart';
import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';

/// La scheda di un capo della valigia generata: perché è lì, se va indossato
/// in partenza, quanti ne ha l'armadio, e "Togli dalla valigia".
///
/// [onQuantity] arriva a ogni cambio dei pezzi (almeno 1, massimo [available]).
/// Lo stepper c'è solo con due pezzi o più nell'armadio. [onRemove] chiude la
/// scheda e toglie l'oggetto. Non salva nulla: lo fa la pagina.
Future<void> showAiPackItemSheet(
  BuildContext context, {
  required TripItem item,
  required int available,
  AiReason? reason,
  bool inDeparture = false,
  required ValueChanged<int> onQuantity,
  required VoidCallback onRemove,
}) => showDsFormSheet<void>(
  context,
  builder: (_) => _AiPackItemSheet(
    item: item,
    available: available,
    reason: reason,
    inDeparture: inDeparture,
    onQuantity: onQuantity,
    onRemove: onRemove,
  ),
);

class _AiPackItemSheet extends StatefulWidget {
  const _AiPackItemSheet({
    required this.item,
    required this.available,
    required this.reason,
    required this.inDeparture,
    required this.onQuantity,
    required this.onRemove,
  });

  final TripItem item;
  final int available;
  final AiReason? reason;
  final bool inDeparture;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  State<_AiPackItemSheet> createState() => _AiPackItemSheetState();
}

class _AiPackItemSheetState extends State<_AiPackItemSheet> {
  /// Pezzi scelti, mostrati nello stepper mentre la scheda è aperta.
  late int _quantity = widget.item.quantity;

  void _change(int quantity) {
    setState(() => _quantity = quantity);
    widget.onQuantity(quantity);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final reason = widget.reason;
    final available = widget.available;
    final haveText = 'trips.pack.ai.have_count'.tr(args: ['$available']);

    return DsFormSheet(
      title: widget.item.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reason != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.spacingMd),
              decoration: BoxDecoration(
                color: context.groupSurface,
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'trips.pack.ai.why_title'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  SizedBox(height: context.spacingXs),
                  Text(reason.label, style: tt.titleMedium?.title),
                  SizedBox(height: context.spacingXs),
                  Text(reason.sentence, style: tt.bodyMedium),
                ],
              ),
            ),
          if (widget.inDeparture) ...[
            SizedBox(height: context.spacingMd),
            Text(
              'trips.pack.ai.in_departure_note'.tr(),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          SizedBox(height: context.spacingMd),
          if (available > 1)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('trips.pack.ai.quantity'.tr(), style: tt.bodyLarge),
                      Text(
                        haveText,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                QuantityStepper(
                  value: _quantity,
                  minValue: 1,
                  maxValue: available,
                  accentColor: cs.onSurface,
                  onChanged: _change,
                ),
              ],
            )
          else
            Text(
              haveText,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          SizedBox(height: context.spacingMd),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('ai_pack_item_remove'),
              style: TextButton.styleFrom(foregroundColor: cs.onSurface),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRemove();
              },
              child: Text('trips.pack.ai.remove'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
