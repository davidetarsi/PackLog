import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../helpers/bottom_sheet_handle.dart';
import '../theme/app_spacing.dart';

/// Bottom sheet generico per la **selezione di un elemento da una lista**.
///
/// Struttura: `BottomSheetHandle → titolo → Divider → ListView` di opzioni.
/// Toccare un'opzione chiude il sheet e restituisce il valore.
///
/// Distinto da [StandardBottomSheetLayout] (usato per form di entità):
/// qui non c'è action bar finale, basta toccare per confermare.
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

  const DsPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.getLabel,
    required this.onSelected,
    this.getSubtitle,
    this.getIcon,
    this.selected,
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
        onSelected: (item) => Navigator.pop(sheetContext, item),
      ),
    );
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
            const BottomSheetHandle(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
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
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final isSelected = item == selected;
                    final iconData = getIcon?.call(item);
                    final subtitle = getSubtitle?.call(item);

                    return ListTile(
                      leading: iconData != null
                          ? Icon(iconData, color: cs.primary)
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
