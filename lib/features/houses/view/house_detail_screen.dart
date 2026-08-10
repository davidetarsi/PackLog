import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/app_pill_tab.dart';
import 'package:pack_log/shared/widgets/sticky_cta_scaffold.dart';
import 'package:pack_log/shared/widgets/tri_slot_bar.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import '../../items/view/add_edit_item_screen.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/providers/item_selection_provider.dart';
import '../../items/widgets/rapid_fire_input.dart';
import '../../tour/tour_keys.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/model/trip_model.dart';
import '../../trips/providers/trip_provider.dart';
import '../../trips/view/trip_picker_sheet.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../../tour/model/onboarding_state.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import 'house_manage_sheet.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/widgets/ds_contextual_app_bar.dart';
import '../../items/view/bulk_move_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/ds_button.dart';

enum _CategoryTab {
  all('trips.filter_all', null),
  vestiti('categories.vestiti', ItemCategory.vestiti),
  toiletries('categories.toiletries', ItemCategory.toiletries),
  elettronica('categories.elettronica', ItemCategory.elettronica),
  varie('categories.varie', ItemCategory.varie);

  final String labelKey;
  final ItemCategory? categoryFilter;
  const _CategoryTab(this.labelKey, this.categoryFilter);
  String get label => labelKey.tr();
}

/// Durata delle transizioni animate tra le due modalità della UI
/// (normale ↔ selezione multipla).
const _kModeSwitchDuration = Duration(milliseconds: 220);
const _kBottomBarElementsHeight = 50.0;

class HouseDetailScreen extends ConsumerStatefulWidget {
  final String houseId;

  const HouseDetailScreen({super.key, required this.houseId});

  @override
  ConsumerState<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends ConsumerState<HouseDetailScreen> {
  /// null = tutti gli item, 'default' = pool generale, spaceId = spazio specifico.
  String? _spaceFilter;
  _CategoryTab _categoryTab = _CategoryTab.all;
  bool _isRapidFireExpanded = false;

  // -------------------------------------------------------------------------
  // Manage sheet
  // -------------------------------------------------------------------------

  void _showManageSheet(
    BuildContext context,
    String houseId,
    bool isPrimary,
    String houseName,
  ) {
    showHouseManageSheet(
      context,
      houseId: houseId,
      isPrimary: isPrimary,
      houseName: houseName,
      onSetPrimary: () => _setPrimaryHouse(context, houseName),
      onDelete: () => _showDeleteDialog(context, houseName),
    );
  }

  // -------------------------------------------------------------------------
  // House actions (delete, set primary)
  // -------------------------------------------------------------------------

  Future<void> _setPrimaryHouse(BuildContext context, String houseName) async {
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        await ref
            .read(houseNotifierProvider.notifier)
            .setPrimaryHouse(widget.houseId);
      },
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.set_primary_failed'.tr(args: [houseName]),
    );

    if (success && context.mounted) {
      AppSnackBar.showSuccess(
        context,
        'houses.primary_house_set'.tr(args: [houseName]),
      );
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, String houseName) async {
    final itemsAsync = ref.read(itemNotifierProvider(widget.houseId));
    final temporaryItems = ref.read(
      temporaryItemsInHouseProvider(widget.houseId),
    );

    final permanentItemsCount = itemsAsync.value?.length ?? 0;
    final temporaryItemsCount = temporaryItems.length;
    final totalItemsCount = permanentItemsCount + temporaryItemsCount;

    if (totalItemsCount > 0) {
      if (!context.mounted) return;

      await DialogHelpers.showInfo(
        context: context,
        title: 'common.error'.tr(),
        message: 'houses.cannot_delete_has_items'.tr(),
        details: [
          if (permanentItemsCount > 0)
            'houses.permanent_items_count'.tr(
              args: [permanentItemsCount.toString()],
            ),
          if (temporaryItemsCount > 0)
            'houses.temporary_items_count'.tr(
              args: [temporaryItemsCount.toString()],
            ),
        ],
      );
      return;
    }

    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.house_type'.tr(),
      itemName: houseName,
    );

    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          await ref
              .read(houseNotifierProvider.notifier)
              .deleteHouse(widget.houseId);
        },
        errorTitle: 'common.error'.tr(),
        errorMessage: 'errors.delete_failed'.tr(args: [houseName]),
      );

      if (success && context.mounted) {
        context.go('/');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Bulk selection actions
  // -------------------------------------------------------------------------

  /// Mostra un dialog di conferma ed elimina in bulk gli item selezionati.
  ///
  /// Usato dall'azione "Elimina" nella selection action bar.
  Future<void> _handleBulkDelete() async {
    final selectionState = ref.read(itemSelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    final count = selectedIds.length;

    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: '',
      itemName: '',
      customTitle: 'items.bulk_delete_confirm_title'.tr(
        args: [count.toString()],
      ),
      customMessage: 'items.bulk_delete_confirm_body'.tr(),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .bulkDelete(selectedIds);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'items.bulk_delete_success'.tr(args: [count.toString()]),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'errors.delete_error'.tr());
      }
    }
  }

  /// Mostra un bottom sheet "Sposta in…" con la lista delle altre case.
  ///
  /// Quando l'utente seleziona una casa di destinazione, chiama [bulkMove] sul
  /// notifier e mostra una snackbar di conferma.
  Future<void> _handleBulkMove() async {
    final selectionState = ref.read(itemSelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    if (!context.mounted) return;

    final dest = await BulkMoveSheet.show(
      context,
      itemCount: selectedIds.length,
      sourceHouseId: widget.houseId,
    );

    if (dest == null || !mounted) return;

    final destinationName = dest.houseDisplayName;
    final count = selectedIds.length;

    try {
      await ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .bulkMove(selectedIds, dest.houseId, spaceId: dest.spaceId);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'items.bulk_move_success'.tr(
            args: [count.toString(), destinationName],
          ),
        );
        final onboardingState = ref
            .read(postLoginOnboardingProvider)
            .valueOrNull;
        if (onboardingState?.step == OnboardingStep.moveItemsTooltip &&
            widget.houseId == onboardingState?.defaultHouseId) {
          // Pop first so MainShell + houseFab are visible before the tooltip fires.
          context.pop();
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) {
            await ref.read(postLoginOnboardingProvider.notifier).advance();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    }
  }

  /// Mostra il picker "scegli un viaggio" e aggiunge gli item selezionati
  /// al viaggio scelto (operazione additiva, idempotente — vedi
  /// [TripRepository.addItemsToTrip]).
  Future<void> _handleAddToTrip() async {
    final selectionState = ref.read(itemSelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    if (!context.mounted) return;

    final trip = await TripPickerSheet.show(context);
    if (trip == null || !mounted) return;

    final allItems =
        ref.read(itemNotifierProvider(widget.houseId)).value ?? const [];
    final selectedItems = allItems
        .where((item) => selectedIds.contains(item.id))
        .toList();

    final tripItems = selectedItems
        .map(
          (item) => TripItem(
            id: item.id,
            name: item.name,
            category: item.category,
            quantity: item.quantity ?? 1,
            originHouseId: item.houseId,
          ),
        )
        .toList();

    final count = tripItems.length;

    try {
      await ref
          .read(tripNotifierProvider.notifier)
          .addItemsToTrip(trip.id, tripItems);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'items.add_to_trip_success'.tr(args: [count.toString(), trip.name]),
        );
        ref.read(itemSelectionNotifierProvider.notifier).clear();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);
    final spacesAsync = ref.watch(spaceNotifierProvider(widget.houseId));
    final allItems =
        ref.watch(itemNotifierProvider(widget.houseId)).value ?? const [];

    final selectionState = ref.watch(itemSelectionNotifierProvider);
    final isSelectionMode = selectionState.isActive;
    final selectedCount = selectionState.selectedIds.length;
    final hasSelection = selectedCount > 0;
    final allItemIds = allItems.map((i) => i.id).toList();

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(itemSelectionNotifierProvider.notifier).clear();
        }
      },
      child: housesAsync.when(
        data: (houses) {
          final matchingHouses = houses.where((h) => h.id == widget.houseId);
          if (matchingHouses.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: Text('houses.house_not_found'.tr())),
              body: DsEmptyState(
                icon: Icons.home_outlined,
                title: 'houses.house_not_found_message'.tr(),
                action: DsButton(
                  label: 'houses.back_to_houses'.tr(),
                  icon: Icons.home,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => context.go('/'),
                ),
              ),
            );
          }

          final house = matchingHouses.first;
          final colorScheme = Theme.of(context).colorScheme;

          return StickyCtaScaffold(
            appBar: DsContextualAppBar(
              isInSelectionMode: isSelectionMode,
              switchDuration: _kModeSwitchDuration,
              normalAppBar: _HouseNormalAppBar(
                colorScheme: colorScheme,
                houseName: house.displayName,
                houseIcon: HouseIcons.getIcon(house.iconName),
              ),
              selectionAppBar: _HouseSelectionAppBar(
                selectedCount: selectedCount,
                allItemIds: allItemIds,
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Riga 1: filtro spazi (solo se esistono spazi) ────────────
                spacesAsync.when(
                  data: (spaces) {
                    // Spazio selezionato eliminato: reset al "tutti"
                    if (_spaceFilter != null &&
                        _spaceFilter != 'default' &&
                        !spaces.any((s) => s.id == _spaceFilter)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _spaceFilter = null);
                      });
                    }
                    if (spaces.isEmpty) return const SizedBox.shrink();
                    return _SpaceFilterPills(
                      spaces: spaces,
                      allItems: allItems,
                      selectedSpaceId: _spaceFilter,
                      onSelected: (id) => setState(() => _spaceFilter = id),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                // ── Riga 2: filtro categorie ──────────────────────────────────
                _CategoryFilterPills(
                  key: tourKeys.houseItemsAnchor,
                  selected: _categoryTab,
                  onSelected: (tab) => setState(() => _categoryTab = tab),
                ),
                // ── Contenuto ─────────────────────────────────────────────────
                Expanded(
                  child: ItemsScreen(
                    houseId: widget.houseId,
                    houseName: house.displayName,
                    selectedSpaceId: _spaceFilter,
                    categoryFilter: _categoryTab.categoryFilter,
                  ),
                ),
              ],
            ),
            // Bottom bar: transizione animata tra barra normale e barra selezione.
            bottomContent: AnimatedSwitcher(
              duration: _kModeSwitchDuration,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: isSelectionMode
                  ? KeyedSubtree(
                      key: const ValueKey('selection_bar'),
                      child: UniversalActionBar(
                        key: const ValueKey('selection-bar'),
                        primaryLabel: 'common.move'.tr(),
                        primaryIcon: Icons.local_shipping_outlined,
                        onPrimaryPressed: hasSelection ? _handleBulkMove : null,
                        leftAction: CircularActionButton(
                          icon: Icons.delete_outline,
                          onPressed: hasSelection ? _handleBulkDelete : null,
                          color: hasSelection
                              ? colorScheme.error
                              : colorScheme.outline,
                          showBorder: true,
                        ),
                        rightAction: CircularActionButton(
                          icon: Icons.luggage_outlined,
                          onPressed: hasSelection ? _handleAddToTrip : null,
                          color: hasSelection
                              ? colorScheme.primary
                              : colorScheme.outline,
                          showBorder: true,
                        ),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('normal_bar'),
                      child: _HouseNormalActionBar(
                        houseId: widget.houseId,
                        isPrimary: house.isPrimary,
                        houseName: house.displayName,
                        isExpanded: _isRapidFireExpanded,
                        currentSpaceId:
                            (_spaceFilter != null && _spaceFilter != 'default')
                            ? _spaceFilter
                            : null,
                        onManage: () => _showManageSheet(
                          context,
                          widget.houseId,
                          house.isPrimary,
                          house.displayName,
                        ),
                        onExpandedChanged: (v) =>
                            setState(() => _isRapidFireExpanded = v),
                      ),
                    ),
            ),
          );
        },
        loading: () => const SkeletonHouseDetailScreen(),
        error: (error, stack) => Scaffold(
          appBar: AppBar(title: Text('common.error'.tr())),
          body: DsErrorState(
            error: error,
            onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget components
// ─────────────────────────────────────────────────────────────────────────────

class _HouseNormalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final ColorScheme colorScheme;
  final String houseName;
  final IconData houseIcon;

  const _HouseNormalAppBar({
    required this.colorScheme,
    required this.houseName,
    required this.houseIcon,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      key: const ValueKey('normal-appbar'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/'),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(houseIcon, color: colorScheme.primary),
          AppSpacing.hGapSm,
          Text(houseName),
        ],
      ),
    );
  }
}

/// AppBar contestuale per la modalità selezione multipla.
/// Mostra il contatore degli item selezionati, un tasto "chiudi" (X) e
/// un tasto "seleziona tutti / deseleziona tutti".
class _HouseSelectionAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  final int selectedCount;
  final List<String> allItemIds;

  const _HouseSelectionAppBar({
    required this.selectedCount,
    required this.allItemIds,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSelected =
        allItemIds.isNotEmpty && selectedCount == allItemIds.length;
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      key: const ValueKey('selection-appbar'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'common.cancel'.tr(),
        onPressed: () =>
            ref.read(itemSelectionNotifierProvider.notifier).clear(),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: Text(
          selectedCount == 0
              ? 'items.select_items'.tr()
              : 'items.selected_count'.tr(args: [selectedCount.toString()]),
          key: ValueKey(selectedCount),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            allSelected
                ? Icons.indeterminate_check_box_outlined
                : Icons.check_box_outlined,
            color: colorScheme.primary,
          ),
          tooltip: allSelected
              ? 'items.deselect_all'.tr()
              : 'items.select_all'.tr(),
          onPressed: () {
            if (allSelected) {
              ref.read(itemSelectionNotifierProvider.notifier).deselectAll();
            } else {
              ref
                  .read(itemSelectionNotifierProvider.notifier)
                  .selectAll(allItemIds);
            }
          },
        ),
      ],
    );
  }
}

/// Bottom action bar in modalità normale: tasto gestisci (sx), rapid-fire
/// (centro), AI import (dx).
class _HouseNormalActionBar extends StatelessWidget {
  final String houseId;
  final bool isPrimary;
  final String houseName;
  final bool isExpanded;
  final String? currentSpaceId;
  final VoidCallback onManage;
  final void Function(bool) onExpandedChanged;

  const _HouseNormalActionBar({
    required this.houseId,
    required this.isPrimary,
    required this.houseName,
    required this.isExpanded,
    required this.currentSpaceId,
    required this.onManage,
    required this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final elementHeight = context.responsive(_kBottomBarElementsHeight);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: TriSlotBar(
        horizontalPadding: 0,
        sideSlotWidth: isExpanded ? 0.0 : elementHeight,
        left: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isExpanded ? 0.0 : 1.0,
          child: isExpanded
              ? null
              : CircularActionButton(
                  icon: Icons.edit,
                  onPressed: onManage,
                  showBorder: true,
                ),
        ),
        center: RapidFireInput(
          houseId: houseId,
          currentSpaceId: currentSpaceId,
          height: elementHeight,
          onOpenFullForm: (name, category) => showAddEditItemSheet(
            context,
            houseId: houseId,
            initialName: name.isNotEmpty ? name : null,
            initialCategory: category,
          ),
          onExpandedChanged: onExpandedChanged,
        ),
        right: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isExpanded ? 0.0 : 1.0,
          child: isExpanded
              ? null
              : CircularActionButton(
                  icon: Icons.auto_awesome,
                  onPressed: () => context.push('/houses/$houseId/ai-import'),
                  showBorder: true,
                ),
        ),
      ),
    );
  }
}

class _SpaceFilterPills extends StatelessWidget {
  final List<SpaceModel> spaces;
  final List<ItemModel> allItems;
  final String? selectedSpaceId;
  final void Function(String?) onSelected;

  const _SpaceFilterPills({
    required this.spaces,
    required this.allItems,
    required this.selectedSpaceId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabItems = <String?>[null, 'default', ...spaces.map((s) => s.id)];
    final generalPoolCount = allItems.where((i) => i.spaceId == null).length;
    final spaceCounts = {
      for (final s in spaces)
        s.id: allItems.where((i) => i.spaceId == s.id).length,
    };

    return Padding(
      padding: EdgeInsets.only(left: context.spacingMd, top: context.spacingSm),
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
        scrollPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _CategoryFilterPills extends StatelessWidget {
  final _CategoryTab selected;
  final void Function(_CategoryTab) onSelected;

  const _CategoryFilterPills({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.spacingMd,
        top: context.spacingSm,
        bottom: context.spacingSm,
      ),
      child: AppPillTab<_CategoryTab>(
        items: _CategoryTab.values,
        selectedItem: selected,
        getLabel: (tab) => tab.label,
        onSelected: onSelected,
        height: 40,
        scrollPadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
      ),
    );
  }
}
