import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_opacity.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/surface_colors.dart';

/// Picker icone a griglia 5×N. Sostituisce i layout custom in
/// [AddEditHouseSheet] e [AddEditSpaceSheet].
///
/// La griglia 5 colonne è coerente con il resto dell'app (es. la palette
/// colori).
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1,
        crossAxisSpacing: context.spacingSm,
        mainAxisSpacing: context.spacingSm,
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
            duration: AppMotion.fast,
            // Come le pill scelte: velo arancio leggero e bordo, niente pieno.
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: AppOpacity.selected)
                  : context.groupSurface,
              border: Border.all(
                color: isSelected ? cs.primary : Colors.transparent,
                width: AppConstants.selectedBorderWidth,
              ),
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
            ),
            child: Icon(
              iconData,
              size: context.iconSizeMd,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
