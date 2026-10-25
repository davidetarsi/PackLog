import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'ds_sheet_header.dart';
import '../theme/app_spacing.dart';
import 'ds_group_header.dart';

/// Bottom sheet generico per la **selezione di un elemento da una lista**.
///
/// Struttura: `[DsSheetHeader] → ListView` di opzioni.
/// Toccare un'opzione chiude il sheet e restituisce il valore.
///
/// Distinto da [DsFormSheet] (usato per form di entità):
/// qui non c'è action bar finale, basta toccare per confermare.
///
/// Con [groupOf] gli elementi consecutivi dello stesso gruppo sono preceduti
/// da un'intestazione con il nome del gruppo (es. la categoria dei tipi di
/// capo). Un gruppo vuoto (`''`) non ha intestazione.
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
    T? selected,
    Widget Function(BuildContext)? footerBuilder,
    String Function(T)? groupOf,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DsPickerSheet<T>(
        title: title,
        items: items,
        getLabel: getLabel,
        getSubtitle: getSubtitle,
        getIcon: getIcon,
        selected: selected,
        footer: footerBuilder?.call(sheetContext),
        groupOf: groupOf,
        onSelected: (item) => Navigator.pop(sheetContext, item),
      ),
    );
  }

  /// Righe della lista: un `String` è un'intestazione di gruppo, un `int` è
  /// l'indice dell'elemento in [items].
  List<Object> get rows {
    final result = <Object>[];
    String? lastGroup;
    for (var index = 0; index < items.length; index++) {
      final group = groupOf?.call(items[index]);
      if (group != null && group.isNotEmpty && group != lastGroup) {
        result.add(group);
      }
      lastGroup = group;
      result.add(index);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSheetHeader(title: title),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    '—',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    if (row is String) {
                      // Stesso margine orizzontale delle righe sotto.
                      final tile =
                          ListTileTheme.of(context).contentPadding?.resolve(
                            Directionality.of(context),
                          ) ??
                          EdgeInsets.symmetric(horizontal: AppSpacing.md);
                      return Padding(
                        padding: EdgeInsets.only(
                          left: tile.left,
                          right: tile.right,
                        ),
                        child: DsGroupHeader(label: row),
                      );
                    }
                    final item = items[row as int];
                    final isSelected = item == selected;
                    final iconData = getIcon?.call(item);
                    final subtitle = getSubtitle?.call(item);

                    return ListTile(
                      leading: iconData != null
                          ? Icon(iconData, color: cs.onSurfaceVariant)
                          : null,
                      title: Text(getLabel(item)),
                      subtitle: subtitle != null ? Text(subtitle) : null,
                      trailing: isSelected
                          ? Icon(Icons.check, color: cs.primary)
                          : null,
                      onTap: () => onSelected(item),
                    );
                  },
                ),
              ),
            if (footer != null) footer!,
            AppSpacing.gapSm,
          ],
        ),
      ),
    );
  }
}
