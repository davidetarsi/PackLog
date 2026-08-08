import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/model/item_model.dart';
import '../model/trip_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../../shared/widgets/universal_item_tile.dart';

/// Widget riutilizzabile per selezionare gli oggetti da portare in viaggio.
///
/// Contiene:
/// - Filtri per casa e categoria
/// - Lista oggetti con icona, nome, quantità e bottoni +/-
class TripItemsSelector extends ConsumerStatefulWidget {
  /// Oggetti già selezionati
  final List<TripItem> selectedItems;

  /// Callback quando la selezione cambia
  final void Function(List<TripItem> items) onSelectionChanged;

  /// Se true, il widget si adatta al contenuto (per uso in scroll parent)
  final bool shrinkWrap;

  const TripItemsSelector({
    super.key,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.shrinkWrap = false,
  });

  @override
  ConsumerState<TripItemsSelector> createState() => _TripItemsSelectorState();
}

class _TripItemsSelectorState extends ConsumerState<TripItemsSelector> {
  String? _selectedHouseId;
  ItemCategory? _selectedCategory;
  late List<TripItem> _items;

  // _accentColor rimosso — usare colorScheme.primary nei build methods.

  // Lista di opzioni categoria (include "Tutto" = null)
  static final List<_CategoryFilterOption> _categoryOptions = [
    _CategoryFilterOption('common.all'.tr(), null),
    ...ItemCategory.values.map(
      (cat) => _CategoryFilterOption(cat.displayName, cat),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.selectedItems);
    // Pre-seleziona la casa primaria così la lista è già popolata all'apertura.
    // Usiamo addPostFrameCallback perché i provider sono accessibili solo
    // dopo il primo build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoSelectPrimaryHouse(),
    );
  }

  void _autoSelectPrimaryHouse() {
    if (!mounted || _selectedHouseId != null) return;
    final houses = ref.read(houseNotifierProvider).valueOrNull;
    if (houses == null) return;
    final primary = houses.where((h) => h.isPrimary).firstOrNull;
    if (primary != null) {
      setState(() => _selectedHouseId = primary.id);
    }
  }

  @override
  void didUpdateWidget(covariant TripItemsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItems != oldWidget.selectedItems) {
      _items = List.from(widget.selectedItems);
    }
  }

  int _getSelectedQuantity(String itemId) {
    final selected = _items.where((i) => i.id == itemId).firstOrNull;
    return selected?.quantity ?? 0;
  }

  /// Raggruppa gli item per categoria rispettando l'ordine canonico
  /// (vestiti → toiletries → elettronica → varie).
  /// Le categorie senza item non compaiono.
  Map<ItemCategory, List<ItemModel>> _groupByCategory(List<ItemModel> items) {
    final map = <ItemCategory, List<ItemModel>>{};
    for (final cat in ItemCategory.values) {
      final grouped = items.where((i) => i.category == cat).toList();
      if (grouped.isNotEmpty) map[cat] = grouped;
    }
    return map;
  }

  void _updateItemQuantity(ItemModel item, String houseId, int newQuantity) {
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
      if (newQuantity > 0) {
        _items.add(
          TripItem(
            id: item.id,
            name: item.name,
            category: item.category,
            quantity: newQuantity,
            originHouseId: houseId,
          ),
        );
      }
    });
    widget.onSelectionChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);

    if (widget.shrinkWrap) {
      // Modalità shrinkWrap per embedding in scroll parent
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilters(context, colorScheme, housesAsync),
          SizedBox(height: context.spacingSm),
          _buildItemsListShrinkWrap(context, colorScheme),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(context, colorScheme, housesAsync),
        SizedBox(height: context.spacingSm),
        Expanded(child: _buildItemsList(context, colorScheme)),
      ],
    );
  }

  Widget _buildFilters(
    BuildContext context,
    ColorScheme colorScheme,
    AsyncValue<List<HouseModel>> housesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtro casa
        // labelMedium (12) contro il titleMedium (16) del titolo di sezione:
        // queste sono etichette di controllo annidate, non sezioni. Prima
        // erano a 16, cioè quasi indistinguibili dal livello sopra.
        Text(
          'common.select_house'.tr(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.spacingSm),
        SizedBox(
          height: 40,
          child: housesAsync.when(
            data: (houses) {
              // Trova l'house selezionato (può essere null)
              final selectedHouse = houses.cast<HouseModel?>().firstWhere(
                (h) => h?.id == _selectedHouseId,
                orElse: () => null,
              );

              return AppPillTab<HouseModel>.nullable(
                items: houses,
                selectedItem: selectedHouse,
                getLabel: (house) => house.displayName,
                getIcon: (house) => Icon(Icons.home_outlined, size: 16),
                onSelected: (house) {
                  setState(() {
                    _selectedHouseId = house?.id;
                  });
                },
                // Rimosso selectedColor per usare il theme default
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => DsErrorState(
              error: e,
              onRetry: () => ref.invalidate(houseNotifierProvider),
            ),
          ),
        ),

        SizedBox(height: context.spacingMd),

        // Filtro categoria
        Text(
          'common.category'.tr(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.spacingSm),
        SizedBox(
          height: 40,
          child: AppPillTab<_CategoryFilterOption>(
            items: _categoryOptions,
            selectedItem: _categoryOptions.firstWhere(
              (opt) => opt.category == _selectedCategory,
            ),
            getLabel: (opt) => opt.label,
            onSelected: (opt) {
              setState(() {
                _selectedCategory = opt.category;
              });
            },
            // Rimossi tutti i colori custom per usare il theme default
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, ColorScheme colorScheme) {
    if (_selectedHouseId == null) {
      return _buildEmptyHouseState(context);
    }

    final itemsAsync = ref.watch(itemNotifierProvider(_selectedHouseId!));

    return itemsAsync.when(
      data: (items) {
        final filteredItems = _selectedCategory == null
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        if (filteredItems.isEmpty) {
          return _buildEmptyItemsState(context);
        }

        // Raggruppa per categoria (ordine canonico: vestiti → toiletries → elettronica → varie)
        final grouped = _groupByCategory(filteredItems);

        // Costruisce la lista piatta con header intercalati
        final rows = <Widget>[];
        for (final entry in grouped.entries) {
          rows.addAll(
            entry.value.map(
              (item) => _buildItemCard(context, colorScheme, item),
            ),
          );
          rows.add(SizedBox(height: context.spacingSm));
        }

        return ListView(
          padding: EdgeInsets.only(
            bottom: context.spacingMd + context.ctaReservedHeight,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: rows,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${'common.error'.tr()}: $e')),
    );
  }

  Widget _buildItemsListShrinkWrap(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    if (_selectedHouseId == null) {
      return _buildEmptyHouseStateShrinkWrap(context);
    }

    final itemsAsync = ref.watch(itemNotifierProvider(_selectedHouseId!));

    return itemsAsync.when(
      data: (items) {
        final filteredItems = _selectedCategory == null
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        if (filteredItems.isEmpty) {
          return _buildEmptyItemsStateShrinkWrap(context);
        }

        // Raggruppa per categoria (ordine canonico: vestiti → toiletries → elettronica → varie)
        final grouped = _groupByCategory(filteredItems);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in grouped.entries) ...[
              //_buildCategoryHeader(context, entry.key),
              ...entry.value.map(
                (item) => _buildItemCard(context, colorScheme, item),
              ),
              SizedBox(height: context.spacingSm),
            ],
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(context.spacingLg),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(context.spacingLg),
        child: Center(child: Text('${'common.error'.tr()}: $e')),
      ),
    );
  }

  /// Stato vuoto casa - versione shrinkWrap (NO scroll interno)
  Widget _buildEmptyHouseStateShrinkWrap(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingLg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_outlined,
              size: context.iconSizeHero,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            SizedBox(height: context.spacingMd),
            Text(
              'trips.select_house_to_view_items'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Stato vuoto items - versione shrinkWrap (NO scroll interno)
  Widget _buildEmptyItemsStateShrinkWrap(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingLg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: context.iconSizeHero,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            SizedBox(height: context.spacingMd),
            Text(
              _selectedCategory == null
                  ? 'common.no_items_in_house'.tr()
                  : 'common.no_items_in_category'.tr(
                      namedArgs: {'category': _selectedCategory!.displayName},
                    ),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHouseState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: context.spacingMd + context.ctaReservedHeight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home_outlined,
                size: context.iconSizeHero,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              SizedBox(height: context.spacingMd),
              Text(
                'trips.select_house_to_view_items'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyItemsState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: context.spacingMd + context.ctaReservedHeight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: context.iconSizeHero,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              SizedBox(height: context.spacingMd),
              Text(
                _selectedCategory == null
                    ? 'common.no_items_in_house'.tr()
                    : 'common.no_items_in_category'.tr(
                        namedArgs: {'category': _selectedCategory!.displayName},
                      ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    ColorScheme colorScheme,
    ItemModel item,
  ) {
    final selectedQuantity = _getSelectedQuantity(item.id);
    final maxQuantity = item.quantity ?? 1;
    final isSelected = selectedQuantity > 0;

    return UniversalItemTile(
      useListTile: false,
      // Nessun riquadro né sfondo, nemmeno da selezionata: lo stato lo porta
      // solo il controllo a destra — checkbox piena per gli oggetti singoli,
      // stepper con accento per quelli a quantità multipla. Tutte le righe
      // restano quindi piatte come in casa e viaggio.
      margin: EdgeInsets.zero,
      contentPadding: EdgeInsets.all(context.spacingSm),
      // L'icona è già colorata in primary: il box grigio dietro era
      // decorazione attorno a un elemento che si legge da solo.
      // Grigio come l'etichetta delle pill non selezionate: la categoria
      // classifica, non è un'azione né uno stato scelto.
      leading: Icon(item.category.icon, color: colorScheme.onSurfaceVariant),
      // Stesso stile del nome oggetto in ItemCard e in TripDetailScreen: era
      // 18/w700 contro il loro 14/w500, cioè lo stesso dato con due pesi
      // diversi a seconda della schermata.
      title: Text(
        item.name,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      // "Disponibili: 1" sotto ogni riga non informa: la disponibilità si
      // mostra solo quando è diversa dal caso implicito.
      subtitle: maxQuantity == 1
          ? null
          : Text(
              'common.available_quantity'.tr(args: [maxQuantity.toString()]),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: maxQuantity == 1
          // Checkbox per quantità singola
          ? Checkbox(
              value: isSelected,
              activeColor: colorScheme.primary,
              onChanged: (_) {
                _updateItemQuantity(
                  item,
                  _selectedHouseId!,
                  isSelected ? 0 : 1,
                );
              },
            )
          // QuantityStepper per quantità multiple (accentColor = primary)
          : QuantityStepper(
              value: selectedQuantity,
              minValue: 0,
              maxValue: maxQuantity,
              accentColor: isSelected ? colorScheme.primary : null,
              onChanged: (qty) =>
                  _updateItemQuantity(item, _selectedHouseId!, qty),
            ),
    );
  }
}

/// Helper class per rappresentare un'opzione di filtro categoria.
/// Wrappa ItemCategory? per essere usata con AppPillTab.
class _CategoryFilterOption {
  final String label;
  final ItemCategory? category;

  const _CategoryFilterOption(this.label, this.category);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CategoryFilterOption &&
          runtimeType == other.runtimeType &&
          category == other.category;

  @override
  int get hashCode => category.hashCode;
}
