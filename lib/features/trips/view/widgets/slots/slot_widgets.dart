import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_checkbox.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../model/ai_packing.dart';
import '../../../model/suitcase_progress.dart';

// I pezzi della valigia fatta di posti nel dettaglio del viaggio: la
// testata "Cosa porti", le informazioni sul viaggio, le card degli
// importanti, le righe "da comprare" e la card dei proposti.
//
// Colori provvisori: l'accento di "Importante" è `onPrimaryContainer`, lo
// stesso degli avvisi della valigia AI; i proposti usano `tertiary` (ambra).

/// "Nome" più "×N" se restano più copie da riempire.
String? _copiesLabel(AiSlot slot) =>
    slot.remaining > 1 ? '×${slot.remaining}' : null;

/// Testata di "Cosa porti".
///
/// Finché c'è un importante aperto ([SuitcaseProgress.sorting]) mostra
/// "N di M pronti" con la barra divisa (tue, proposte) e la legenda; poi le
/// spunte di sempre, "N di M in valigia". Con [SuitcaseProgress.isEmpty] non
/// va mostrata: il chiamante mette lo stato vuoto.
class SuitcaseProgressHeader extends StatelessWidget {
  const SuitcaseProgressHeader({super.key, required this.progress});

  final SuitcaseProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final countStyle = tt.labelLarge?.copyWith(color: cs.onSurfaceVariant);

    if (!progress.sorting) {
      final total = progress.packTotal;
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppConstants.pillBorderRadius,
              ),
              child: LinearProgressIndicator(
                key: const Key('trip_detail_progress'),
                value: total == 0 ? 0 : progress.checked / total,
                minHeight: context.spacingXs,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.onSurface,
              ),
            ),
          ),
          SizedBox(width: context.spacingSm),
          Text(
            'trips.detail.packed_count'.tr(
              args: ['${progress.checked}', '$total'],
            ),
            style: countStyle,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _ReadyBar(progress: progress)),
            SizedBox(width: context.spacingSm),
            Text(
              'trips.detail.ready_count'.tr(
                args: ['${progress.ready}', '${progress.readyTotal}'],
              ),
              style: countStyle,
            ),
          ],
        ),
        SizedBox(height: context.spacingSm),
        Wrap(
          spacing: context.spacingMd,
          runSpacing: context.spacingXs,
          children: [
            _LegendEntry(
              dot: _LegendDot(color: cs.onSurface),
              label: 'trips.detail.legend_mine'.tr(args: ['${progress.mine}']),
            ),
            _LegendEntry(
              dot: _LegendDot(color: cs.tertiary),
              label: 'trips.detail.legend_proposed'.tr(
                args: ['${progress.proposed}'],
              ),
            ),
            _LegendEntry(
              dot: _LegendDot(outline: cs.onSurfaceVariant),
              label: 'trips.detail.legend_important'.tr(
                args: ['${progress.importantOpen}'],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// La barra di "N di M pronti": prima le tue, poi le proposte, il resto
/// (gli importanti da sistemare) è il fondo vuoto.
class _ReadyBar extends StatelessWidget {
  const _ReadyBar({required this.progress});

  final SuitcaseProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final segments = [
      (progress.mine, cs.onSurface),
      (progress.proposed, cs.tertiary),
      (progress.importantOpen, cs.surfaceContainerHighest),
    ];
    return ClipRRect(
      key: const Key('trip_detail_ready_progress'),
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      child: SizedBox(
        height: context.spacingXs,
        // Senza stretch i segmenti, che non hanno figli, restano alti zero.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (flex, color) in segments)
              if (flex > 0)
                Expanded(
                  flex: flex,
                  child: ColoredBox(color: color),
                ),
          ],
        ),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.dot, required this.label});

  final Widget dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        SizedBox(width: context.spacingXs),
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

/// Pallino della legenda: pieno con [color], vuoto con il bordo [outline].
class _LegendDot extends StatelessWidget {
  const _LegendDot({this.color, this.outline});

  final Color? color;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final border = outline;
    return Container(
      width: context.spacingSm,
      height: context.spacingSm,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
    );
  }
}

/// Un'informazione sul viaggio ("Prevedi una lavanderia"): icona, titolo e
/// perché, con i testi del server.
class TripNoteRow extends StatelessWidget {
  const TripNoteRow({super.key, required this.note});

  final AiTripNote note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: context.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: context.iconSizeSm,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: tt.bodyLarge?.strong),
                SizedBox(height: context.spacingXxs),
                Text(
                  note.why,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etichetta "Importante" con la bandierina, nel colore [color].
class _ImportantLabel extends StatelessWidget {
  const _ImportantLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag_outlined, size: context.iconSizeXs, color: color),
        SizedBox(width: context.spacingXs),
        Text(
          'trips.slots.important'.tr(),
          style: tt.labelLarge?.strong.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Card di un posto importante aperto: "Importante", nome (×N), motivo in
/// una riga e due azioni testuali, l'aggiunta ([AiSlot.addLabel]) e "Da
/// comprare". Niente bottoni pieni.
class ImportantSlotCard extends StatelessWidget {
  const ImportantSlotCard({
    super.key,
    required this.slot,
    required this.onAdd,
    required this.onToBuy,
  });

  final AiSlot slot;
  final VoidCallback onAdd;
  final VoidCallback onToBuy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = _copiesLabel(slot);
    final reason = slot.reason;

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          top: context.spacingMd,
          bottom: context.spacingXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImportantLabel(color: cs.onPrimaryContainer),
                  SizedBox(height: context.spacingXs),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          slot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium,
                        ),
                      ),
                      if (copies != null) ...[
                        SizedBox(width: context.spacingXs),
                        Text(
                          copies,
                          style: tt.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    SizedBox(height: context.spacingXxs),
                    Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Il testo dei bottoni ha già il suo margine: la riga parte poco
            // più a sinistra, così le parole si allineano al nome.
            Padding(
              padding: EdgeInsets.only(left: context.spacingXs),
              child: Wrap(
                children: [
                  DsTextButton(
                    key: Key('slot_add_${slot.id}'),
                    label: slot.addLabel,
                    onPressed: onAdd,
                  ),
                  DsTextButton(
                    key: Key('slot_to_buy_${slot.id}'),
                    label: 'trips.slots.to_buy'.tr(),
                    onPressed: onToBuy,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga di un importante segnato "da comprare": più spenta della card,
/// "Importante · Da comprare", il nome e "Presa", che apre la barra per
/// riempirlo.
class ToBuySlotRow extends StatelessWidget {
  const ToBuySlotRow({super.key, required this.slot, required this.onGotIt});

  final AiSlot slot;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurfaceVariant;
    final copies = _copiesLabel(slot);

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          left: context.spacingMd,
          right: context.spacingXs,
          top: context.spacingSm,
          bottom: context.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ImportantLabel(color: muted),
                      Text(' · ', style: tt.labelLarge?.copyWith(color: muted)),
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: context.iconSizeXs,
                        color: muted,
                      ),
                      SizedBox(width: context.spacingXs),
                      Flexible(
                        child: Text(
                          'trips.slots.to_buy'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacingXxs),
                  Text(
                    copies == null ? slot.name : '${slot.name} $copies',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            DsTextButton(
              key: Key('slot_got_it_${slot.id}'),
              label: 'trips.slots.got_it'.tr(),
              onPressed: onGotIt,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card dei proposti di PackLog in un gruppo: bordo col gradiente, fermo;
/// in cima la scintilla e "Proposti da PackLog · tocca per mettere i tuoi".
///
/// Ogni riga ha la scintilla, il nome, ×N e la freccina; quando non si sta
/// più sistemando ([sorting] falso) al posto della scintilla c'è la casella,
/// che cambia `checked`. Il tocco sulla riga chiama [onOpen]. I posti
/// "da comprare" vanno in fondo.
class ProposedSlotsCard extends StatelessWidget {
  const ProposedSlotsCard({
    super.key,
    required this.slots,
    required this.sorting,
    required this.onOpen,
    required this.onToggle,
  });

  final List<AiSlot> slots;
  final bool sorting;
  final ValueChanged<AiSlot> onOpen;
  final ValueChanged<AiSlot> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ordered = [
      ...slots.where((s) => !s.toBuy),
      ...slots.where((s) => s.toBuy),
    ];

    return PackLogGradientBorder(
      radius: AppConstants.cardBorderRadius,
      child: Material(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacingMd,
                context.spacingMd,
                context.spacingMd,
                context.spacingXs,
              ),
              child: Row(
                children: [
                  PackLogSparkle(size: context.iconSizeSm),
                  SizedBox(width: context.spacingXs),
                  Expanded(
                    child: Text(
                      'trips.slots.proposed_header'.tr(),
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final slot in ordered)
              _ProposedRow(
                slot: slot,
                sorting: sorting,
                onTap: () => onOpen(slot),
                onToggle: () => onToggle(slot),
              ),
            SizedBox(height: context.spacingXs),
          ],
        ),
      ),
    );
  }
}

class _ProposedRow extends StatelessWidget {
  const _ProposedRow({
    required this.slot,
    required this.sorting,
    required this.onTap,
    required this.onToggle,
  });

  final AiSlot slot;
  final bool sorting;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = _copiesLabel(slot);
    final packed = !sorting && slot.checked;

    return InkWell(
      key: Key('slot_row_${slot.id}'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: context.spacingSm,
          right: context.spacingMd,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Row(
            children: [
              if (sorting)
                SizedBox.square(
                  dimension: kMinInteractiveDimension,
                  child: Center(
                    child: PackLogSparkle(size: context.iconSizeSm),
                  ),
                )
              else
                DsCheckbox(value: slot.checked, onChanged: (_) => onToggle()),
              SizedBox(width: context.spacingXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        color: packed ? context.textTertiary : cs.onSurface,
                        decoration: packed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (slot.toBuy)
                      Text(
                        'trips.slots.to_buy'.tr(),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (copies != null) ...[
                SizedBox(width: context.spacingSm),
                Text(
                  copies,
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              SizedBox(width: context.spacingXs),
              Icon(
                Icons.chevron_right,
                size: context.iconSizeMd,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
