import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/shared/theme/app_motion.dart';
import 'package:pack_log/shared/widgets/sticky_cta_scaffold.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../ai_input/helpers/start_ai_scan.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import '../../items/providers/item_provider.dart';
import '../../items/providers/item_selection_provider.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/ds_error_state.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../kits/view/widgets/kit_strip.dart';
import '../../spaces/providers/space_provider.dart';
import 'house_manage_sheet.dart';
import '../../../shared/widgets/ds_contextual_app_bar.dart';
import '../../../shared/widgets/height_reporter.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../kits/view/add_selection_to_kit.dart';
import 'widgets/house_actions.dart';
import 'widgets/house_bulk_actions.dart';
import 'widgets/house_add_page.dart';
import 'widgets/house_normal_action_bar.dart';
import 'widgets/house_normal_app_bar.dart';
import 'widgets/house_selection_app_bar.dart';
import 'widgets/house_selection_bar.dart';
import 'widgets/space_filter_pills.dart';

/// Durata delle transizioni animate tra le due modalità della UI
/// (normale ↔ selezione multipla).
const _kModeSwitchDuration = AppMotion.medium;

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

  /// Ultima altezza riportata dalla barra normale (serve alla pagina
  /// "aggiungi" per riservare lo spazio della CTA).
  double? _normalActionBarHeight;

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
      onSetPrimary: () => setPrimaryHouse(context, ref, houseId, houseName),
      onDelete: () => showDeleteHouseDialog(context, ref, houseId, houseName),
      onSelectItems: () =>
          ref.read(itemSelectionNotifierProvider.notifier).toggleMode(),
    );
  }

  void _onNormalActionBarHeight(double height) {
    if (!mounted || height == _normalActionBarHeight) return;
    if (_isAdding) {
      setState(() => _normalActionBarHeight = height);
    } else {
      _normalActionBarHeight = height;
    }
  }

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
        // Su Android il primo Back lo consuma la tastiera: il focus resta sul
        // campo mentre lei scompare. Si toglie solo il focus, così la ricerca
        // resta aperta e i risultati coperti dalla tastiera tornano visibili;
        // il Back successivo chiude la ricerca.
        _searchFocus.unfocus();
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
            ctaHeightOverride: _isAdding
                ? StickyCtaScaffold.standardHeight(context) -
                      context.responsive(AppConstants.ctaHeight) +
                      (_normalActionBarHeight ??
                          context.responsive(kHouseBottomBarHeight) +
                              MediaQuery.viewInsetsOf(context).bottom)
                : null,
            appBar: DsContextualAppBar(
              isInSelectionMode: isSelectionMode,
              switchDuration: _kModeSwitchDuration,
              normalAppBar: HouseNormalAppBar(
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
              selectionAppBar: HouseSelectionAppBar(
                selectedCount: selectedCount,
                allItemIds: allItemIds,
              ),
            ),
            body: _isAdding
                ? addBaseline == null
                      // Gli oggetti non sono ancora arrivati: pagina vuota.
                      ? const SizedBox.shrink()
                      : AddPage(
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
                          return SpaceFilterPills(
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
                      // ── Riga 2: kit (non durante selezione e ricerca) ──────
                      if (!isSelectionMode && _search == null)
                        KitStrip(houseId: widget.houseId),
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
                        ? HouseSelectionBar(
                            key: const ValueKey('selection-bar'),
                            hasSelection: hasSelection,
                            onMove: () =>
                                handleBulkMove(context, ref, widget.houseId),
                            onKit: () => addSelectionToKit(
                              context,
                              ref,
                              houseId: widget.houseId,
                            ),
                            onTrip: () =>
                                handleAddToTrip(context, ref, widget.houseId),
                            onDelete: () =>
                                handleBulkDelete(context, ref, widget.houseId),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('normal_bar'),
                            child: HeightReporter(
                              onHeightChanged: _onNormalActionBarHeight,
                              child: HouseNormalActionBar(
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
