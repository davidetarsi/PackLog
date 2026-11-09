import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/app_pill_tab.dart';
import '../../../items/model/item_model.dart';
import '../../../spaces/model/space_model.dart';

class SpaceFilterPills extends StatelessWidget {
  final List<SpaceModel> spaces;
  final List<ItemModel> allItems;
  final String? selectedSpaceId;
  final void Function(String?) onSelected;

  const SpaceFilterPills({
    super.key,
    required this.spaces,
    required this.allItems,
    required this.selectedSpaceId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // "Senza spazio" chiude la riga: prima "Tutti", poi gli spazi.
    final tabItems = <String?>[null, ...spaces.map((s) => s.id), 'default'];
    final generalPoolCount = allItems.where((i) => i.spaceId == null).length;
    final spaceCounts = {
      for (final s in spaces)
        s.id: allItems.where((i) => i.spaceId == s.id).length,
    };

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: context.spacingMd,
        top: context.spacingSm,
        bottom: context.spacingXs,
      ),
      child: AppPillTab<String?>.nullable(
        items: tabItems,
        selectedItem: selectedSpaceId,
        getLabel: (spaceId) {
          if (spaceId == null) return 'spaces.all_items'.tr();
          if (spaceId == 'default') {
            return '${'spaces.default'.tr()} ($generalPoolCount)';
          }
          final space = spaces.firstWhere((s) => s.id == spaceId);
          return '${space.name} (${spaceCounts[spaceId] ?? 0})';
        },
        onSelected: onSelected,
        // Il filtro scelto è uno stato di lettura, non l'azione della
        // schermata: niente arancio.
        selectedColor: colorScheme.onSurface,
        selectedTextColor: colorScheme.onSurface,
        scrollPadding: EdgeInsets.zero,
      ),
    );
  }
}
