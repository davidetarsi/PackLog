import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/widgets/ds_form_sheet.dart';
import '../../../model/ai_packing.dart';
import 'ai_reason_point_item.dart';
import 'ai_reason_section.dart';
import 'ai_reason_slot_item.dart';

/// I posti di [level] che il foglio spiega: ancora aperti e non "da comprare",
/// importanti compresi (gli importanti da comprare restano in valigia come riga
/// spenta, ma si spiegano nella vista "Da comprare"). L'ordine è quello ricevuto.
List<AiSlot> reasonSlots(List<AiSlot> slots, AiSlotLevel level) => [
  for (final slot in slots)
    if (slot.level == level && slot.isOpen && !slot.toBuy) slot,
];

/// Il sottotitolo della riga "Perché queste scelte": "2 importanti · 3
/// suggeriti · Tutti i giorni, Pioggia". Le parti vuote non ci sono.
String reasonsSummary({
  required List<AiSlot> important,
  required List<AiReasonPoint> reasons,
  required List<AiSlot> suggested,
}) => [
  if (important.isNotEmpty)
    'trips.pack.ai.reasons_count_important'.plural(important.length),
  if (suggested.isNotEmpty)
    'trips.pack.ai.reasons_count_suggested'.plural(suggested.length),
  if (reasons.isNotEmpty)
    [for (final reason in reasons.take(4)) reason.title].join(', '),
].join(' · ');

/// Il foglio dei motivi, in tre sezioni nell'ordine della valigia: gli
/// importanti ancora aperti, i suggeriti ancora aperti, i punti dall'armadio. Le sezioni vuote non ci
/// sono. Si apre solo se almeno una ha qualcosa.
class AiReasonsSheet extends StatelessWidget {
  const AiReasonsSheet({
    super.key,
    required this.important,
    required this.reasons,
    required this.suggested,
  });

  final List<AiSlot> important;
  final List<AiReasonPoint> reasons;
  final List<AiSlot> suggested;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DsFormSheet(
      title: 'trips.pack.ai.reasons_row'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (important.isNotEmpty)
            AiReasonSection(
              key: const Key('ai_reasons_important'),
              icon: Icons.flag_outlined,
              title: 'trips.pack.ai.reasons_important'.tr(),
              color: cs.primary,
              children: [
                for (final slot in important) AiReasonSlotItem(slot: slot),
              ],
            ),
          if (suggested.isNotEmpty)
            AiReasonSection(
              key: const Key('ai_reasons_suggested'),
              icon: Icons.auto_awesome,
              title: 'trips.pack.ai.reasons_suggested'.tr(),
              color: cs.tertiary,
              children: [
                for (final slot in suggested) AiReasonSlotItem(slot: slot),
              ],
            ),
          if (reasons.isNotEmpty)
            AiReasonSection(
              key: const Key('ai_reasons_wardrobe'),
              icon: Icons.checkroom_outlined,
              title: 'trips.pack.ai.reasons_wardrobe'.tr(),
              color: cs.onSurface,
              children: [
                for (final point in reasons) AiReasonPointItem(point: point),
              ],
            ),
        ],
      ),
    );
  }
}
