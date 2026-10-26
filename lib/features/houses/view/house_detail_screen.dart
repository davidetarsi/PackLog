import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/app_pill_tab.dart';
import 'package:pack_log/shared/widgets/sticky_cta_scaffold.dart';
import 'package:pack_log/shared/widgets/ds_floating_bar.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../ai_input/helpers/start_ai_scan.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import '../../items/view/item_card.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/providers/item_selection_provider.dart';
import '../../items/widgets/rapid_fire_input.dart';
import '../../tour/tour_keys.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/constants/app_constants.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/model/trip_model.dart';
import '../../trips/providers/trip_provider.dart';
import '../../trips/view/trip_picker_sheet.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import 'house_manage_sheet.dart';
import '../../../shared/widgets/ds_contextual_app_bar.dart';
import '../../items/view/bulk_move_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/helpers/navigation_helpers.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/helpers/search_match.dart';

/// Durata delle transizioni animate tra le due modalità della UI
/// (normale ↔ selezione multipla).
const _kModeSwitchDuration = Duration(milliseconds: 220);
const _kBottomBarElementsHeight = 50.0;

class HouseDetailScreen extends ConsumerStatefulWidget {
  final String houseId;

  /// Apre la schermata con il rapid fire già attivo (tastiera su): è la
  /// strada dell'inserimento a mano dal foglio Crea.
  final bool openRapidFire;

  const HouseDetailScreen({
    super.key,
    required this.houseId,
    this.openRapidFire = false,
  });

  @override
  ConsumerState<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends ConsumerState<HouseDetailScreen> {
  /// null = tutti gli item, 'default' = pool generale, spaceId = spazio specifico.
  String? _spaceFilter;
  bool _isRapidFireExpanded = false;

  /// Ricerca nella casa: `null` = chiusa, stringa (anche vuota) = aperta.
  String? _search;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchKeyboardWasVisible = false;

  /// Ultima ricerca senza risultati già registrata: invio e chiusura della
  /// stessa ricerca contano una volta sola.
  String? _lastReportedQuery;

  /// Focus del rapid fire, condiviso con lo stato vuoto: "scrivili a mano"
  /// apre la pagina "aggiungi" mettendo il focus qui.
  final _rapidFireFocus = FocusNode();

  /// Pagina "aggiungi" aperta: il campo rapid fire ha il focus. Il
  /// [_addBaseline] sono gli id degli oggetti presenti quando si è aperta
  /// (quelli nuovi sono gli "Aggiunti ora"); si cattura al primo build con
  /// gli oggetti caricati, perché aprendo la pagina subito possono mancare.
  bool _isAdding = false;
  Set<String>? _addBaseline;

  /// Testo del campo: resta anche a pagina chiusa, il campo lo ricorda.
  String _addQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _rapidFireFocus.dispose();
    super.dispose();
  }

  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  void _openSearch() {
    _analytics.trackSearchOpened(context: 'house');
    _searchController.clear();
    // Il campo rapid-fire perde il focus: la ricerca prende la tastiera.
    FocusManager.instance.primaryFocus?.unfocus();
    _lastReportedQuery = null;
    setState(() => _search = '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _search == null ||
          _isAdding ||
          ref.read(itemSelectionNotifierProvider).isActive) {
        return;
      }
      _searchFocus.requestFocus();
    });
  }

  /// Chiamato all'invio della tastiera e alla chiusura: una ricerca che non
  /// ha trovato niente è il segnale che serve, una per tentativo. Il filtro
  /// è lo stesso della lista (spazio scelto e temporanei compresi).
  void _reportIfNoResults() {
    final query = _search?.trim() ?? '';
    if (query.isEmpty || query == _lastReportedQuery) return;
    final items =
        ref.read(itemNotifierProvider(widget.houseId)).valueOrNull ?? const [];
    final temporaries = ref.read(temporaryItemsInHouseProvider(widget.houseId));
    final found =
        visibleHouseItems(
          items,
          spaceId: _spaceFilter,
          query: query,
        ).isNotEmpty ||
        visibleTemporaries(
          temporaries,
          spaceId: _spaceFilter,
          query: query,
        ).isNotEmpty;
    if (found) return;
    _lastReportedQuery = query;
    _analytics.trackSearchNoResults(
      context: 'house',
      queryLength: query.length,
    );
  }

  void _closeSearch() {
    _reportIfNoResults();
    _lastReportedQuery = null;
    _searchController.clear();
    setState(() => _search = null);
  }

  void _onRapidFireExpanded(bool expanded) {
    // La ricerca e la pagina aggiungi non stanno insieme nell'intestazione:
    // chi prende il focus è il campo, quindi la ricerca si chiude.
    if (expanded && _search != null) _closeSearch();
    setState(() {
      _isRapidFireExpanded = expanded;
      if (expanded) {
        _isAdding = true;
      } else if (ModalRoute.of(context)?.isCurrent ?? true) {
        // Il campo ha perso il focus perché si è usciti (indietro, tocco
        // fuori): la pagina si chiude. Se invece sopra c'è un foglio (la
        // scheda di un oggetto aperta da qui) la pagina resta, e al ritorno
        // il focus torna sul campo.
        _isAdding = false;
        _addBaseline = null;
      }
    });
  }

  void _closeAddPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isAdding = false;
      _addBaseline = null;
      _isRapidFireExpanded = false;
    });
  }

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
      onSelectItems: () =>
          ref.read(itemSelectionNotifierProvider.notifier).toggleMode(),
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
    final searchKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final searchKeyboardWasDismissed =
        _searchKeyboardWasVisible && !searchKeyboardVisible;
    _searchKeyboardWasVisible = searchKeyboardVisible;
    if (searchKeyboardWasDismissed &&
        _search != null &&
        _searchFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _search == null ||
            !_searchFocus.hasFocus ||
            MediaQuery.viewInsetsOf(context).bottom > 0 ||
            !(ModalRoute.of(context)?.isCurrent ?? true)) {
          return;
        }
        // Su Android il Back può essere consumato dall'IME per prima: il focus
        // resta sul campo mentre la tastiera scompare. Chiudiamo la ricerca
        // insieme alla tastiera invece di lasciare uno stato intermedio.
        _closeSearch();
      });
    }

    final housesAsync = ref.watch(houseNotifierProvider);
    final spacesAsync = ref.watch(spaceNotifierProvider(widget.houseId));
    final allItems =
        ref.watch(itemNotifierProvider(widget.houseId)).value ?? const [];

    final selectionState = ref.watch(itemSelectionNotifierProvider);
    final isSelectionMode = selectionState.isActive;
    final selectedCount = selectionState.selectedIds.length;
    final hasSelection = selectedCount > 0;
    // "Seleziona tutti" prende solo gli oggetti visibili (ricerca e spazio).
    final loadedItems = ref
        .watch(itemNotifierProvider(widget.houseId))
        .valueOrNull;
    if (_isAdding && _addBaseline == null && loadedItems != null) {
      _addBaseline = {for (final item in loadedItems) item.id};
    }
    final addBaseline = _addBaseline;
    final allItemIds = visibleHouseItems(
      allItems,
      spaceId: _spaceFilter,
      query: _search ?? '',
    ).map((i) => i.id).toList();

    return PopScope(
      canPop: !isSelectionMode && _search == null && !_isAdding,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isSelectionMode) {
          ref.read(itemSelectionNotifierProvider.notifier).clear();
        } else if (_search != null) {
          _closeSearch();
        } else if (_isAdding) {
          _closeAddPage();
        }
      },
      child: housesAsync.when(
        data: (houses) {
          final matchingHouses = houses.where((h) => h.id == widget.houseId);
          if (matchingHouses.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: Text('houses.house_not_found'.tr())),
              body: DsNotFoundState(
                icon: Icons.home_outlined,
                title: 'houses.house_not_found'.tr(),
                actionLabel: 'houses.back_to_houses'.tr(),
                onAction: () => context.go('/'),
              ),
            );
          }

          final house = matchingHouses.first;

          return StickyCtaScaffold(
            appBar: DsContextualAppBar(
              isInSelectionMode: isSelectionMode,
              switchDuration: _kModeSwitchDuration,
              normalAppBar: _HouseNormalAppBar(
                houseName: house.displayName,
                onEditHouse: () =>
                    showAddEditHouseSheet(context, houseId: widget.houseId),
                searchController: _search == null ? null : _searchController,
                searchFocusNode: _searchFocus,
                onSearchOpen: _openSearch,
                onSearchChanged: (q) => setState(() => _search = q),
                onSearchSubmitted: _reportIfNoResults,
                onSearchClose: _closeSearch,
                isAdding: _isAdding,
                onCloseAdding: _closeAddPage,
                onManage: () => _showManageSheet(
                  context,
                  widget.houseId,
                  house.isPrimary,
                  house.displayName,
                ),
              ),
              selectionAppBar: _HouseSelectionAppBar(
                selectedCount: selectedCount,
                allItemIds: allItemIds,
              ),
            ),
            body: _isAdding
                ? addBaseline == null
                      // Gli oggetti non sono ancora arrivati: pagina vuota.
                      ? const SizedBox.shrink()
                      : _AddPage(
                          houseId: widget.houseId,
                          query: _addQuery,
                          baselineIds: addBaseline,
                          onExistingOpened: (position) => _analytics
                              .trackAddExistingMatchTapped(position: position),
                          onSheetClosed: () {
                            // La scheda chiusa riporta il focus sul campo: la
                            // pagina resta usabile senza un altro tocco.
                            if (mounted && _isAdding) {
                              _rapidFireFocus.requestFocus();
                            }
                          },
                        )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Riga 1: filtro spazi (solo se esistono spazi) ──────
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
                            onSelected: (id) =>
                                setState(() => _spaceFilter = id),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      // ── Contenuto ───────────────────────────────────────────
                      Expanded(
                        child: ItemsScreen(
                          houseId: widget.houseId,
                          houseName: house.displayName,
                          selectedSpaceId: _spaceFilter,
                          searchQuery: _search,
                          onSearchResultOpened: (position) =>
                              _analytics.trackSearchResultTapped(
                                context: 'house',
                                position: position,
                              ),
                          onWriteManually: _rapidFireFocus.requestFocus,
                        ),
                      ),
                    ],
                  ),
            // Bottom bar: transizione animata tra barra normale e barra selezione.
            bottomContent: _search != null && !isSelectionMode
                ? null
                : AnimatedSwitcher(
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
                        ? DsFloatingBar(
                            key: const ValueKey('selection-bar'),
                            children: [
                              DsBarItem(
                                key: const Key('selection_move'),
                                icon: Icons.drive_file_move_outline,
                                label: 'common.move'.tr(),
                                onTap: hasSelection ? _handleBulkMove : null,
                              ),
                              DsBarItem(
                                key: const Key('selection_trip'),
                                icon: Icons.luggage_outlined,
                                label: 'items.to_trip'.tr(),
                                onTap: hasSelection ? _handleAddToTrip : null,
                              ),
                              DsBarItem(
                                key: const Key('selection_delete'),
                                icon: Icons.delete_outline,
                                label: 'common.delete'.tr(),
                                onTap: hasSelection ? _handleBulkDelete : null,
                              ),
                            ],
                          )
                        : KeyedSubtree(
                            key: const ValueKey('normal_bar'),
                            child: _HouseNormalActionBar(
                              houseId: widget.houseId,
                              onAiScan: () =>
                                  startAiScan(context, ref, widget.houseId),
                              autofocusRapidFire: widget.openRapidFire,
                              isExpanded: _isRapidFireExpanded,
                              currentSpaceId:
                                  (_spaceFilter != null &&
                                      _spaceFilter != 'default')
                                  ? _spaceFilter
                                  : null,
                              focusNode: _rapidFireFocus,
                              onTextChanged: (q) =>
                                  setState(() => _addQuery = q),
                              onExpandedChanged: _onRapidFireExpanded,
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
            title: 'errors.load_houses'.tr(),
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

  const _HouseNormalAppBar({
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
        leading: IconButton(
          key: const Key('house_search_close'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'common.back'.tr(),
          onPressed: onSearchClose,
        ),
        title: TextField(
          key: const Key('house_search_field'),
          controller: controller,
          focusNode: searchFocusNode,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          onSubmitted: (_) => onSearchSubmitted(),
          decoration: InputDecoration(
            hintText: 'houses.search_hint'.tr(args: [houseName]),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'common.clear'.tr(),
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                  ),
          ),
        ],
      );
    }

    return AppBar(
      key: const ValueKey('normal-appbar'),
      leading: isAdding
          // Dentro il gruppo del rapid fire: il tocco non chiude il campo
          // prima di arrivare al bottone, che chiude la pagina da sé.
          ? TapRegion(
              groupId: rapidFireTapRegionGroup,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'common.back'.tr(),
                onPressed: onCloseAdding,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
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
              IconButton(
                key: const Key('house_search'),
                icon: const Icon(Icons.search),
                tooltip: 'houses.search_tooltip'.tr(),
                onPressed: onSearchOpen,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'houses.manage_sheet_title'.tr(),
                onPressed: onManage,
              ),
            ],
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
              : 'items.selected_count'.plural(selectedCount),
          key: ValueKey(selectedCount),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final notifier = ref.read(itemSelectionNotifierProvider.notifier);
            allSelected
                ? notifier.deselectAll()
                : notifier.selectAll(allItemIds);
          },
          child: Text(
            allSelected ? 'items.deselect_all'.tr() : 'items.select_all'.tr(),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

/// Pagina "aggiungi": mentre si scrive nel rapid fire la casa sparisce e
/// restano solo le risposte utili. "Già in casa": oggetti presenti
/// all'apertura che somigliano al testo. "Aggiunti ora": quelli salvati in
/// questa pagina. Vuota se non c'è niente da dire.
class _AddPage extends ConsumerWidget {
  final String houseId;
  final String query;
  final Set<String> baselineIds;
  final void Function(int position) onExistingOpened;

  /// La scheda di un oggetto aperta dalla pagina si è chiusa.
  final VoidCallback onSheetClosed;

  const _AddPage({
    required this.houseId,
    required this.query,
    required this.baselineIds,
    required this.onExistingOpened,
    required this.onSheetClosed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(itemNotifierProvider(houseId)).valueOrNull ??
        const <ItemModel>[];
    final quantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(houseId),
    );
    final matches = query.trim().length < 2
        ? const <ItemModel>[]
        : items
              .where(
                (i) =>
                    baselineIds.contains(i.id) && matchesSearch(i.name, query),
              )
              .toList();
    final added = items.where((i) => !baselineIds.contains(i.id)).toList();

    Widget card(ItemModel item, {VoidCallback? onOpened}) => ItemCard(
      item: item,
      houseId: houseId,
      quantityOnTrip: quantitiesOnTrip[item.id] ?? 0,
      onOpened: onOpened,
      // Qui la selezione non parte: il campo resta il centro della pagina.
      allowSelection: false,
      onSheetClosed: onSheetClosed,
    );

    return SingleChildScrollView(
      key: const Key('house_add_page'),
      padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
      // Solo il contenuto è "dentro" il campo: toccare lo spazio vuoto sotto
      // chiude la pagina, toccare una riga apre l'oggetto.
      child: TapRegion(
        groupId: rapidFireTapRegionGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (matches.isNotEmpty) ...[
              DsGroupHeader(
                label: 'items.already_here'.tr(),
                count: matches.length,
              ),
              for (final (i, item) in matches.indexed)
                card(item, onOpened: () => onExistingOpened(i + 1)),
            ],
            if (added.isNotEmpty) ...[
              DsGroupHeader(label: 'items.added_now'.tr(), count: added.length),
              for (final item in added) card(item),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom action bar in modalità normale: campo rapid-fire (sinistra) e
/// scansione AI (destra). "⋮" e ricerca stanno nell'intestazione.
class _HouseNormalActionBar extends StatelessWidget {
  final String houseId;
  final VoidCallback onAiScan;
  final bool autofocusRapidFire;
  final bool isExpanded;
  final String? currentSpaceId;
  final void Function(bool) onExpandedChanged;
  final FocusNode focusNode;
  final ValueChanged<String> onTextChanged;

  const _HouseNormalActionBar({
    required this.houseId,
    required this.onAiScan,
    required this.autofocusRapidFire,
    required this.isExpanded,
    required this.currentSpaceId,
    required this.onExpandedChanged,
    required this.focusNode,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final elementHeight = context.responsive(_kBottomBarElementsHeight);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: RapidFireInput(
              houseId: houseId,
              autofocus: autofocusRapidFire,
              currentSpaceId: currentSpaceId,
              height: elementHeight,
              onExpandedChanged: onExpandedChanged,
              onTextChanged: onTextChanged,
              focusNode: focusNode,
            ),
          ),
          // Mentre si scrive il campo prende tutta la riga.
          if (!isExpanded) ...[
            SizedBox(width: context.spacingSm),
            CircularActionButton(
              icon: Icons.auto_awesome,
              // L'unico arancio della schermata: la scansione AI è la strada
              // che vogliamo far prendere per aggiungere oggetti.
              color: Theme.of(context).colorScheme.primary,
              showBorder: true,
              onPressed: onAiScan,
            ),
          ],
        ],
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
