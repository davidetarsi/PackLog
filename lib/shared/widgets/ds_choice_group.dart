import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'ds_choice_pill.dart';
import 'ds_field_label.dart';

/// Gruppo di pillole di scelta con titolo evidente (es. "Colore", "Calore").
///
/// Regole di scelta, con [onChanged] che riceve sempre l'insieme nuovo:
/// - singola e obbligatoria: toccare la scelta attuale non emette nulla;
/// - singola e facoltativa: toccare la scelta attuale la toglie (insieme vuoto);
/// - multipla: tocco = inverti; se obbligatoria non si può svuotare.
///
/// [note] sta sulla stessa riga del titolo, in grigio. Con [doubt] la nota
/// diventa "?" + testo in onSurface; senza [note] resta solo l'icona.
/// [trailing] va in coda alle pillole (es. "+ Altro colore").
class DsChoiceGroup<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiple;

  /// Non si può restare senza scelta.
  final bool required;

  /// Già tradotta dal chiamante.
  final String? note;
  final bool doubt;
  final Widget? trailing;

  const DsChoiceGroup({
    super.key,
    required this.title,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.multiple = false,
    this.required = true,
    this.note,
    this.doubt = false,
    this.trailing,
  });

  void _handleTap(T option) {
    final isSelected = selected.contains(option);
    final Set<T> next;
    if (multiple) {
      next = {...selected};
      if (isSelected) {
        next.remove(option);
      } else {
        next.add(option);
      }
      if (required && next.isEmpty) return;
    } else if (isSelected) {
      if (required) return;
      next = {};
    } else {
      next = {option};
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacingLg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: DsFieldLabel.prominentStyle(context)),
              if (doubt || note != null) ...[
                SizedBox(width: context.spacingSm),
                if (doubt)
                  Icon(
                    Icons.help_outline,
                    size: context.iconSizeSm,
                    color: cs.onSurface,
                  ),
                if (doubt && note != null)
                  SizedBox(width: context.spacingXs / 2),
                if (note != null)
                  Text(
                    note!,
                    style: tt.bodySmall?.copyWith(
                      color: doubt ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
        Wrap(
          spacing: context.spacingXs,
          children: [
            for (final option in options)
              DsChoicePill(
                label: labelOf(option),
                selected: selected.contains(option),
                onTap: () => _handleTap(option),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}
