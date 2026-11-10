import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/shared/theme/app_motion.dart';
import '../../../../shared/widgets/ds_icon_button.dart';
import '../../../../shared/widgets/ds_text_button.dart';
import '../../../items/providers/item_selection_provider.dart';

/// AppBar contestuale per la modalità selezione multipla.
/// Mostra il contatore degli item selezionati, un tasto "chiudi" (X) e
/// un tasto "seleziona tutti / deseleziona tutti".
class HouseSelectionAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  final int selectedCount;
  final List<String> allItemIds;

  const HouseSelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.allItemIds,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSelected =
        allItemIds.isNotEmpty && selectedCount == allItemIds.length;
    return AppBar(
      key: const ValueKey('selection-appbar'),
      leading: DsIconButton(
        icon: Icons.close,
        tooltip: 'common.cancel'.tr(),
        onPressed: () =>
            ref.read(itemSelectionNotifierProvider.notifier).clear(),
      ),
      title: AnimatedSwitcher(
        duration: AppMotion.medium,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: Text(
          selectedCount == 0
              ? 'items.select_items'.tr()
              : 'items.selected_count'.plural(selectedCount),
          key: ValueKey(selectedCount),
        ),
      ),
      actions: [
        DsTextButton(
          onPressed: () {
            final notifier = ref.read(itemSelectionNotifierProvider.notifier);
            allSelected
                ? notifier.deselectAll()
                : notifier.selectAll(allItemIds);
          },
          label: allSelected
              ? 'items.deselect_all'.tr()
              : 'items.select_all'.tr(),
        ),
      ],
    );
  }
}
