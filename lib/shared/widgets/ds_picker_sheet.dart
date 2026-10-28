import 'package:flutter/material.dart';

import 'ds_form_sheet.dart';
import 'ds_group_header.dart';
import 'ds_settings.dart';

/// Foglio per la **selezione di un elemento da una lista**.
///
/// Struttura: [DsFormSheet] (testata con la x, trascinamento) → un
/// [DsSettingsGroup] per gruppo di righe. Toccare una riga chiude il foglio e
/// restituisce il valore.
///
/// Distinto dai fogli di entità (form con CTA): qui non c'è action bar finale,
/// basta toccare per confermare.
///
/// Con [groupOf] gli elementi consecutivi dello stesso gruppo stanno in un
/// blocco preceduto da un'intestazione con il nome del gruppo (es. la categoria
/// dei tipi di capo). Un gruppo vuoto (`''`) non ha intestazione.
///
/// Uso tipico:
/// ```dart
/// final house = await DsPickerSheet.show<HouseModel>(
///   context: context,
///   title: 'trips.select_destination_house'.tr(),
///   items: houses,
///   getLabel: (h) => h.name,
///   getIcon: (h) => Icons.home_outlined,
///   selected: _selectedHouse,
/// );
/// if (house != null) setState(() => _selectedHouse = house);
/// ```
class DsPickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) getLabel;
  final String? Function(T)? getSubtitle;
  final IconData? Function(T)? getIcon;

  /// Widget di inizio riga al posto dell'icona, per es. la bandiera della
  /// lingua. Se restituisce `null` vale [getIcon].
  final Widget? Function(T)? getLeading;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Widget? footer;

  /// Gruppo di ogni elemento, per le intestazioni (vedi la classe).
  final String Function(T)? groupOf;

  const DsPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.getLabel,
    required this.onSelected,
    this.getSubtitle,
    this.getIcon,
    this.getLeading,
    this.selected,
    this.footer,
    this.groupOf,
  });

  /// Mostra il picker sheet e restituisce il valore selezionato (null se
  /// l'utente chiude senza selezionare).
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) getLabel,
    String? Function(T)? getSubtitle,
    IconData? Function(T)? getIcon,
    Widget? Function(T)? getLeading,
    T? selected,
    Widget Function(BuildContext)? footerBuilder,
    String Function(T)? groupOf,
  }) {
    return showDsSheet<T>(
      context,
      builder: (sheetContext) => DsPickerSheet<T>(
        title: title,
        items: items,
        getLabel: getLabel,
        getSubtitle: getSubtitle,
        getIcon: getIcon,
        getLeading: getLeading,
        selected: selected,
        footer: footerBuilder?.call(sheetContext),
        groupOf: groupOf,
        onSelected: (item) => Navigator.pop(sheetContext, item),
      ),
    );
  }

  /// Gruppi in ordine: ogni gruppo ha il nome (null se non ne ha) e gli indici
  /// dei suoi elementi in [items]. Un cambio di gruppo apre un nuovo blocco.
  List<({String? label, List<int> indices})> get _sections {
    final result = <({String? label, List<int> indices})>[];
    String? lastGroup;
    for (var index = 0; index < items.length; index++) {
      final group = groupOf?.call(items[index]);
      if (result.isEmpty || group != lastGroup) {
        result.add((
          label: group == null || group.isEmpty ? null : group,
          indices: <int>[],
        ));
      }
      result.last.indices.add(index);
      lastGroup = group;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DsFormSheet(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Center(
              child: Text(
                '—',
                style: textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final section in _sections) ...[
              if (section.label != null) DsGroupHeader(label: section.label!),
              DsSettingsGroup(
                children: [
                  for (final index in section.indices) _row(context, index, cs),
                ],
              ),
            ],
          if (footer != null) footer!,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int index, ColorScheme cs) {
    final item = items[index];
    final iconData = getIcon?.call(item);
    final leading =
        getLeading?.call(item) ??
        (iconData != null ? Icon(iconData, color: cs.onSurfaceVariant) : null);
    final subtitle = getSubtitle?.call(item);

    return DsSettingsRow(
      key: ValueKey('picker_item_$index'),
      leading: leading,
      label: getLabel(item),
      subtitle: subtitle,
      trailing: item == selected ? Icon(Icons.check, color: cs.primary) : null,
      onTap: () => onSelected(item),
    );
  }
}
