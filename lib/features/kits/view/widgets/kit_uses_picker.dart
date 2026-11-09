import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_choices.dart';
import '../../../../core/catalog/catalog_provider.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_choice_group.dart';
import '../../../../shared/widgets/ds_choice_pill.dart';
import '../../helpers/kit_uses_choice.dart';

/// Quante pillole si vedono prima di "Altre", oltre a quelle scelte.
const int _kCollapsedCount = 3;

/// "Lo aggiungo da solo ai viaggi con… (facoltativo)": le pillole delle
/// attività e dei mezzi, con la frase che spiega quelle scelte dal nome.
/// Chiusa mostra le scelte e poche altre; "Altre" apre tutte.
class KitUsesPicker extends ConsumerStatefulWidget {
  const KitUsesPicker({
    super.key,
    required this.choice,
    required this.onToggle,
  });

  final KitUsesChoice choice;
  final ValueChanged<String> onToggle;

  @override
  ConsumerState<KitUsesPicker> createState() => _KitUsesPickerState();
}

class _KitUsesPickerState extends ConsumerState<KitUsesPicker> {
  bool _expanded = false;

  /// Le pillole viste scelte almeno una volta: toglierne una non la fa
  /// sparire da sotto il dito.
  final Set<String> _seen = {};

  @override
  Widget build(BuildContext context) {
    // Il catalogo può cambiare in background.
    ref.watch(catalogRevisionProvider);
    final selected = widget.choice.selected;
    List<String> options(String domain) => daProporre(
      vociDi(domain, activeOnly: false),
      giaUsate: selected,
      dominio: domain,
    );
    final activities = options('activity');
    final all = [...activities, ...options('transport')];
    String labelOf(String id) =>
        etichettaDi(activities.contains(id) ? 'activity' : 'transport', id);
    _seen.addAll(selected);
    final shown = _expanded
        ? all
        : [
            for (final (i, id) in all.indexed)
              if (i < _kCollapsedCount || _seen.contains(id)) id,
          ];
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsChoiceGroup<String>(
          title: 'kits.uses_title'.tr(),
          note: 'kits.optional'.tr(),
          noteBelow: true,
          options: shown,
          labelOf: labelOf,
          selected: selected,
          multiple: true,
          required: false,
          // L'insieme nuovo differisce da quello vecchio per la pillola toccata.
          onChanged: (next) {
            final toggled = {
              ...next.difference(selected),
              ...selected.difference(next),
            };
            if (toggled.isNotEmpty) widget.onToggle(toggled.first);
          },
          trailing: _expanded
              ? null
              : DsChoicePill(
                  key: const Key('kit_uses_more'),
                  label: 'kits.more_pills'.tr(),
                  selected: false,
                  onTap: () => setState(() => _expanded = true),
                ),
        ),
        if (widget.choice.proposed.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: context.spacingXs),
            child: Text(
              'kits.uses_guessed'.tr(
                args: [widget.choice.proposed.map(labelOf).join(', ')],
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
