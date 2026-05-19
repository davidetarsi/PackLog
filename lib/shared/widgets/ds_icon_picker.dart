import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Picker icone a griglia 5×N. Sostituisce i layout custom in
/// [HouseFormContent] (GridView 5xN) e [SpaceFormContent] (Wrap).
///
/// La griglia 5 colonne è coerente con il resto dell'app (palette colori,
/// gender picker in TemplateSelectionScreen, ecc.).
///
/// ```dart
/// DsIconPicker(
///   icons: HouseIcons.all,
///   selectedId: _selectedIconName,
///   onSelected: (name) => setState(() => _selectedIconName = name),
/// )
/// ```
class DsIconPicker extends StatelessWidget {
  /// Mappa `id → IconData` delle icone disponibili.
  final Map<String, IconData> icons;

  /// ID dell'icona attualmente selezionata (null = nessuna).
  final String? selectedId;

  /// Callback invocata quando l'utente seleziona un'icona.
  final ValueChanged<String> onSelected;

  /// Permette la deselezione (tap sull'icona già selezionata → null).
  final ValueChanged<String?>? onDeselected;

  const DsIconPicker({
    super.key,
    required this.icons,
    required this.selectedId,
    required this.onSelected,
    this.onDeselected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final iconName = icons.keys.elementAt(index);
        final iconData = icons.values.elementAt(index);
        final isSelected = iconName == selectedId;

        return InkWell(
          onTap: () {
            if (isSelected && onDeselected != null) {
              onDeselected!(null);
            } else {
              onSelected(iconName);
            }
          },
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : cs.surface,
              border: Border.all(
                color: isSelected ? cs.primary : cs.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
            ),
            child: Icon(
              iconData,
              size: 26,
              color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        );
      },
    );
  }
}
