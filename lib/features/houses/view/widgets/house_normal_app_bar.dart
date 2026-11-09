import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/helpers/navigation_helpers.dart';
import '../../../../shared/widgets/ds_icon_button.dart';
import '../../../../shared/widgets/ds_search_field.dart';
import '../../../items/widgets/rapid_fire_input.dart';
import '../../../tour/tour_keys.dart';

class HouseNormalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String houseName;

  /// Tocco sul nome: apre la modifica di nome, luogo e icona.
  final VoidCallback onEditHouse;

  /// Non nullo quando la ricerca è aperta: l'intestazione diventa il campo.
  final TextEditingController? searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onSearchOpen;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchClose;

  /// La pagina "aggiungi" è aperta: niente 🔍 né ⋮, la freccia la chiude.
  final bool isAdding;
  final VoidCallback onCloseAdding;
  final VoidCallback onManage;

  const HouseNormalAppBar({
    super.key,
    required this.houseName,
    required this.onEditHouse,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchOpen,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchClose,
    required this.isAdding,
    required this.onCloseAdding,
    required this.onManage,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final controller = searchController;

    if (controller != null) {
      return AppBar(
        key: const ValueKey('search-appbar'),
        leading: DsIconButton(
          key: const Key('house_search_close'),
          icon: Icons.arrow_back,
          tooltip: 'common.back'.tr(),
          onPressed: onSearchClose,
        ),
        title: DsSearchField(
          key: const Key('house_search_field'),
          inBar: true,
          controller: controller,
          focusNode: searchFocusNode,
          hintText: 'houses.search_hint'.tr(args: [houseName]),
          onChanged: onSearchChanged,
          onSubmitted: (_) => onSearchSubmitted(),
        ),
      );
    }

    return AppBar(
      key: const ValueKey('normal-appbar'),
      leading: isAdding
          // Dentro il gruppo del rapid fire: il tocco non chiude il campo
          // prima di arrivare al bottone, che chiude la pagina da sé.
          ? TapRegion(
              groupId: rapidFireTapRegionGroup,
              child: DsIconButton(
                icon: Icons.arrow_back,
                tooltip: 'common.back'.tr(),
                onPressed: onCloseAdding,
              ),
            )
          : DsIconButton(
              icon: Icons.arrow_back,
              tooltip: 'common.back'.tr(),
              onPressed: () => context.popOrGo('/'),
            ),
      // Solo il nome, senza icona: l'icona serve a distinguere le case nella
      // lista, qui si sa già dove si è. Toccarlo apre la modifica, come
      // "Modifica info" nel menu ⋮.
      title: InkWell(
        key: tourKeys.houseTitle,
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        onTap: isAdding ? null : onEditHouse,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacingXs),
          child: Text(houseName, overflow: TextOverflow.ellipsis),
        ),
      ),
      actions: isAdding
          ? null
          : [
              DsIconButton(
                key: const Key('house_search'),
                icon: Icons.search,
                tooltip: 'houses.search_tooltip'.tr(),
                onPressed: onSearchOpen,
              ),
              DsIconButton(
                icon: Icons.more_vert,
                tooltip: 'houses.manage_sheet_title'.tr(),
                onPressed: onManage,
              ),
            ],
    );
  }
}
