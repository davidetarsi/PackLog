import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../../items/model/item_model.dart';
import '../../../../items/widgets/rapid_fire_input.dart';
import '../../../model/ai_packing.dart';

/// La barra in fondo al dettaglio viaggio mentre si riempie un posto: sopra il
/// campo il chip di contesto ("Magliette · 3 da personalizzare", con la X per
/// chiudere), a lato "Da comprare", sotto il Rapid Fire della casa di
/// partenza.
///
/// Ogni invio crea l'oggetto nella casa ([RapidFireInput] fa tutto) e lo passa
/// a [onItemCreated]; chi la usa lo mette in valigia e scala il posto. La
/// barra non sa quando chiudersi da sola: lo decide chi la mostra (X, indietro
/// o posto esaurito). Il tasto indietro di Android chiude prima la barra.
///
/// L'aspetto definitivo si rifinisce in una sessione a parte: qui conta il
/// comportamento, con i pezzi del design system.
class SlotRapidFireBar extends StatelessWidget {
  const SlotRapidFireBar({
    super.key,
    required this.slot,
    required this.houseId,
    required this.onItemCreated,
    required this.onClose,
    this.onToBuy,
  });

  final AiSlot slot;

  /// La casa di partenza: gli oggetti nascono lì.
  final String houseId;
  final ValueChanged<ItemModel> onItemCreated;
  final VoidCallback onClose;

  /// "Da comprare" a lato; `null` lo nasconde (il posto lo è già).
  final VoidCallback? onToBuy;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      // Indietro chiude la barra; il campo, se è a fuoco, riceve lo stesso
      // evento e toglie la tastiera.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      // Opaca: la fascia di vetro lascia intravedere la lista, e le righe non
      // devono passare sotto il chip e i bottoni.
      child: ColoredBox(
        color: context.groundSurface,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _ContextChip(
                      label: 'trips.slots.context_chip'.tr(
                        args: [slot.name, '${slot.remaining}'],
                      ),
                      onClose: onClose,
                    ),
                  ),
                  if (onToBuy != null)
                    DsTextButton(
                      key: const Key('slot_bar_to_buy'),
                      label: 'trips.slots.to_buy'.tr(),
                      onPressed: onToBuy,
                    ),
                ],
              ),
              SizedBox(height: context.spacingXs),
              RapidFireInput(
                // Un altro posto, un campo nuovo.
                key: ValueKey('slot_bar_input_${slot.id}'),
                houseId: houseId,
                autofocus: true,
                hintText: 'trips.slots.rapid_fire_hint'.tr(),
                onItemCreated: onItemCreated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il posto che si sta riempiendo, con la X per chiudere.
class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label, required this.onClose});

  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.iconSizeLg),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: context.spacingMd),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PackLogSparkle(size: context.iconSizeSm),
            SizedBox(width: context.spacingXs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(color: cs.onSurface),
              ),
            ),
            DsIconButton(
              key: const Key('slot_bar_close'),
              tooltip: 'common.close'.tr(),
              icon: Icons.close,
              color: cs.onSurfaceVariant,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
