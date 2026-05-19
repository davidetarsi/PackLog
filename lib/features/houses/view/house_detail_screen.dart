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
import '../../trips/providers/trip_items_status_provider.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../../spaces/view/spaces_management_screen.dart';
import '../../luggages/view/luggages_management_screen.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/widgets/ds_contextual_app_bar.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';

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
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('houses.edit_info'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                showAddEditHouseSheet(context, houseId: houseId);
              },
            ),
            ListTile(
              leading: Icon(
                Icons
                    .push_pin, // push_pin per "casa principale" — bookmark riservato ai viaggi salvati
                color: isPrimary
                    ? null
                    : Theme.of(sheetContext).colorScheme.primary,
              ),
              title: Text('houses.set_as_primary'.tr()),
              enabled: !isPrimary,
              onTap: isPrimary
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      _setPrimaryHouse(context, houseName);
                    },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.meeting_room),
              title: Text('spaces.manage'.tr()),
              onTap: () async {
                Navigator.pop(sheetContext);
                await showSpacesManagementSheet(context, houseId: houseId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.luggage),
              title: Text('luggages.manage'.tr()),
              onTap: () async {
                Navigator.pop(sheetContext);
                await showLuggagesManagementSheet(context, houseId: houseId);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'common.delete'.tr(),
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteDialog(context, houseName);
              },
            ),
          ],
        ),
      ),
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

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text('common.error'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('houses.cannot_delete_has_items'.tr()),
                const SizedBox(height: 16),
                if (permanentItemsCount > 0)
                  Text(
                    '• ${'houses.permanent_items_count'.tr(args: [permanentItemsCount.toString()])}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                if (temporaryItemsCount > 0)
                  Text(
                    '• ${'houses.temporary_items_count'.tr(args: [temporaryItemsCount.toString()])}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('common.ok'.tr()),
              ),
            ],
          );
        },
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
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'items.bulk_delete_confirm_title'.tr(args: [count.toString()]),
        ),
        content: Text('items.bulk_delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
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

    final allHouses = ref.read(houseNotifierProvider).value ?? [];
    final otherHouses = allHouses.where((h) => h.id != widget.houseId).toList();

    if (!context.mounted) return;

    final destination = await DsPickerSheet.show(
      context: context,
      title: 'items.bulk_move_title'.tr(),
      items: otherHouses,
      getLabel: (h) => h.name,
      getSubtitle: (h) => h.isPrimary ? 'houses.primary'.tr() : null,
      getIcon: (h) => HouseIcons.getIcon(h.iconName),
    );

    if (destination == null || !mounted) return;

    final destinationName = destination.name;
    final count = selectedIds.length;

    try {
      await ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .bulkMove(selectedIds, destination.id);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'items.bulk_move_success'.tr(
            args: [count.toString(), destinationName],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    }
  }

  // -------------------------------------------------------------------------
  // AppBar builders
  // -------------------------------------------------------------------------

  /// AppBar standard (modalità normale).
  AppBar _buildNormalAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    String houseName,
    IconData houseIcon,
  ) {
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
          const SizedBox(width: 8),
          Text(houseName),
        ],
      ),
    );
  }

  /// AppBar contestuale (modalità selezione multipla).
  ///
  /// Mostra il contatore degli item selezionati, un tasto "chiudi" (X) e
  /// un tasto "seleziona tutti".
  AppBar _buildSelectionAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    int selectedCount,
    List<String> allItemIds,
  ) {
    final allSelected =
        allItemIds.isNotEmpty && selectedCount == allItemIds.length;

    return AppBar(
      key: const ValueKey('selection-appbar'),
      // Tasto X: esce dalla modalità selezione e pulisce lo stato.
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
        // Bottone "seleziona tutti" / "deseleziona tutti"
        IconButton(
          icon: Icon(
            allSelected ? Icons.indeterminate_check_box_outlined : Icons.check_box_outlined,
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

  // -------------------------------------------------------------------------
  // Action bar builders
  // -------------------------------------------------------------------------

  void _openFullFormFromRapidFire(
    String houseId,
    String name,
    ItemCategory category,
  ) {
    showAddEditItemSheet(
      context,
      houseId: houseId,
      initialName: name.isNotEmpty ? name : null,
      initialCategory: category,
    );
  }

  /// Bottom action bar standard (modalità normale).
  Widget _buildNormalActionBar(
    BuildContext context,
    ColorScheme colorScheme,
    String houseId,
    bool isPrimary,
    String houseName,
  ) {
    final elementHeight = context.responsive(_kBottomBarElementsHeight);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: TriSlotBar(
        horizontalPadding: 0,
        sideSlotWidth: _isRapidFireExpanded ? 0.0 : elementHeight,
        left: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isRapidFireExpanded ? 0.0 : 1.0,
          child: _isRapidFireExpanded
              ? null
              : CircularActionButton(
                  icon: Icons.edit,
                  onPressed: () =>
                      _showManageSheet(context, houseId, isPrimary, houseName),
                  showBorder: true,
                ),
        ),
        center: RapidFireInput(
          houseId: houseId,
          currentSpaceId: (_spaceFilter != null && _spaceFilter != 'default')
              ? _spaceFilter
              : null,
          height: elementHeight,
          onOpenFullForm: (name, category) =>
              _openFullFormFromRapidFire(houseId, name, category),
          onExpandedChanged: (expanded) {
            setState(() => _isRapidFireExpanded = expanded);
          },
        ),
        right: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isRapidFireExpanded ? 0.0 : 1.0,
          child: _isRapidFireExpanded
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

  // -------------------------------------------------------------------------
  // Filter pills
  // -------------------------------------------------------------------------

  Widget _buildSpacePills(
    BuildContext context,
    List<SpaceModel> spaces,
    List<ItemModel> allItems,
  ) {
    final tabItems = <String?>[null, 'default', ...spaces.map((s) => s.id)];
    final generalPoolCount = allItems.where((i) => i.spaceId == null).length;
    final spaceCounts = {
      for (final s in spaces)
        s.id: allItems.where((i) => i.spaceId == s.id).length,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: context.spacingMd,
        top: context.spacingSm,
      ),
      child: AppPillTab<String?>.nullable(
        items: tabItems,
        selectedItem: _spaceFilter,
        getLabel: (spaceId) {
          if (spaceId == null) return 'spaces.all_items'.tr();
          if (spaceId == 'default') {
            return '${'spaces.default'.tr()} ($generalPoolCount)';
          }
          final space = spaces.firstWhere((s) => s.id == spaceId);
          return '${space.name} (${spaceCounts[spaceId] ?? 0})';
        },
        onSelected: (String? spaceId) =>
            setState(() => _spaceFilter = spaceId),
        scrollPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCategoryPills(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.spacingMd,
        top: context.spacingSm,
        bottom: context.spacingSm,
      ),
      child: AppPillTab<_CategoryTab>(
        items: _CategoryTab.values,
        selectedItem: _categoryTab,
        getLabel: (tab) => tab.label,
        onSelected: (tab) => setState(() => _categoryTab = tab),
        height: 40,
        scrollPadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);
    final spacesAsync = ref.watch(spacesByHouseProvider(widget.houseId));
    final allItems =
        ref.watch(itemNotifierProvider(widget.houseId)).value ??
        const [];

    // Stato della selezione multipla: osservato globalmente qui e propagato
    // verso il basso tramite il provider (ItemCard lo osserva autonomamente).
    final selectionState = ref.watch(itemSelectionNotifierProvider);
    final isSelectionMode = selectionState.isActive;
    final selectedCount = selectionState.selectedIds.length;
    final hasSelection = selectedCount > 0;

    // IDs di tutti gli item permanenti della casa: servono per "seleziona tutti".
    final allItemIds = allItems.map((i) => i.id).toList();

    return housesAsync.when(
      data: (houses) {
        final matchingHouses = houses.where((h) => h.id == widget.houseId);
        if (matchingHouses.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('houses.house_not_found'.tr())),
            body: EmptyState(
              icon: Icons.home_outlined,
              title: 'houses.house_not_found_message'.tr(),
              action: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: Text('houses.back_to_houses'.tr()),
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
            normalAppBar: _buildNormalAppBar(
              context,
              colorScheme,
              house.name,
              HouseIcons.getIcon(house.iconName),
            ),
            selectionAppBar: _buildSelectionAppBar(
              context,
              colorScheme,
              selectedCount,
              allItemIds,
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
                  return _buildSpacePills(context, spaces, allItems);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              // ── Riga 2: filtro categorie ──────────────────────────────────
              _buildCategoryPills(context),
              // ── Contenuto ─────────────────────────────────────────────────
              Expanded(
                child: ItemsScreen(
                  houseId: widget.houseId,
                  houseName: house.name,
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
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: isSelectionMode
                ? KeyedSubtree(
                    key: const ValueKey(
                      'selection_bar',
                    ), // Aiuta l'AnimatedSwitcher
                    /// Bottom action bar contestuale (modalità selezione multipla).
                    ///
                    /// - Sinistra: elimina gli item selezionati (disabilitato se nessuno scelto)
                    /// - Centro: sposta gli item selezionati (disabilitato se nessuno scelto)
                    child: UniversalActionBar(
                      key: const ValueKey('selection-bar'),
                      horizontalPadding: 0,
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
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey(
                      'normal_bar',
                    ), // Aiuta l'AnimatedSwitcher
                    child: _buildNormalActionBar(
                      context,
                      colorScheme,
                      widget.houseId,
                      house.isPrimary,
                      house.name,
                    ),
                  ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('common.error'.tr())),
        body: ErrorState(
          error: error,
          onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
