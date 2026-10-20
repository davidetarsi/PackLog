import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_steps.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../ai_input/helpers/start_ai_scan.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../luggages/model/luggage_model.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../../luggages/view/luggages_management_screen.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import 'widgets/pack/pack_parts.dart';
import 'widgets/pack/pack_summary_line.dart';
import 'widgets/trip_edit_placeholder.dart';
import 'widgets/trip_section_title.dart';

/// Prepara la valigia di un viaggio: riepilogo, bagagli e oggetti.
///
/// È la stessa pagina per il passo 2 di "Nuovo viaggio" ([fromNewTrip]), per
/// "Modifica oggetti" e per la cartolina. Il salvataggio è esplicito, con
/// "Fatto": fino ad allora niente si scrive.
class PackSuitcaseScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// Passo 2 del nuovo viaggio: in cima si mostra l'indicatore dei passi.
  final bool fromNewTrip;

  const PackSuitcaseScreen({
    super.key,
    required this.tripId,
    this.fromNewTrip = false,
  });

  @override
  ConsumerState<PackSuitcaseScreen> createState() => _PackSuitcaseScreenState();
}

class _PackSuitcaseScreenState extends ConsumerState<PackSuitcaseScreen> {
  /// Copia del viaggio, presa una volta sola: vedi [_hydrate].
  TripModel? _trip;

  /// Oggetti del viaggio, per id. È la selezione: cambiare casa non la tocca.
  Map<String, TripItem> _items = {};
  Map<String, TripItem> _initialItems = {};

  /// Bagagli del viaggio, per id.
  Map<String, LuggageModel> _luggages = {};
  Map<String, LuggageModel> _initialLuggages = {};

  /// Casa scelta dal selettore; `null` finché non se ne sceglie una.
  String? _pickedHouseId;

  /// Testo della ricerca, in minuscolo.
  String _query = '';

  /// Vero mentre il viaggio si salva: il bottone resta del suo colore.
  bool _saving = false;

  /// Copia il viaggio nello stato modificabile, una volta sola.
  ///
  /// Nessun `setState`: siamo dentro il build provocato da `ref.watch`.
  void _hydrate(TripModel trip) {
    if (_trip != null) return;
    _trip = trip;
    _items = {for (final item in trip.items) item.id: item};
    _initialItems = {..._items};
    _luggages = {for (final luggage in trip.luggages) luggage.id: luggage};
    _initialLuggages = {..._luggages};
  }

  /// Vero se la selezione o i bagagli non sono più quelli di apertura.
  bool get _isDirty {
    final itemsChanged =
        _items.length != _initialItems.length ||
        _items.entries.any((entry) => _initialItems[entry.key] != entry.value);
    final luggagesChanged =
        _luggages.length != _initialLuggages.length ||
        _luggages.keys.any((id) => !_initialLuggages.containsKey(id));
    return itemsChanged || luggagesChanged;
  }

  /// La casa mostrata in "Cosa porti": quella scelta, altrimenti la proposta.
  HouseModel? _houseFor(List<HouseModel> houses) {
    final picked = _pickedHouseId;
    if (picked != null) {
      for (final house in houses) {
        if (house.id == picked) return house;
      }
    }
    return _proposedHouse(houses);
  }

  /// La casa proposta è la principale. Se la principale è la meta del viaggio,
  /// la prima altra casa; se non ce n'è un'altra, resta la principale.
  HouseModel? _proposedHouse(List<HouseModel> houses) {
    final primary = defaultDestinationHouse(houses);
    if (primary == null) return null;
    if (primary.id != _trip?.destinationHouseId) return primary;
    return houses.where((house) => house.id != primary.id).firstOrNull ??
        primary;
  }

  /// Normalizza i [TripItem] con [TripItem.originHouseId] vuoto recuperando la
  /// casa reale dell'[ItemModel] corrispondente. Idempotente: sistema i dati
  /// creati prima che il campo venisse introdotto.
  Future<List<TripItem>> _normalizeItemOrigins(List<TripItem> items) async {
    final itemRepo = ref.read(itemRepositoryProvider);
    return Future.wait(
      items.map((tripItem) async {
        if (tripItem.originHouseId.isNotEmpty) return tripItem;
        try {
          final itemModel = await itemRepo.getItemById(tripItem.id);
          return tripItem.copyWith(originHouseId: itemModel.houseId);
        } catch (_) {
          return tripItem;
        }
      }),
    );
  }

  /// Spunta un oggetto della casa mostrata, o la toglie. Un oggetto nuovo entra
  /// con quantità 1 e non spuntato; uno tolto esce dalla selezione.
  void _toggleItem(ItemModel item, String houseId) {
    setState(() {
      if (_items.containsKey(item.id)) {
        _items.remove(item.id);
      } else {
        _items[item.id] = TripItem(
          id: item.id,
          name: item.name,
          category: item.category,
          quantity: 1,
          originHouseId: houseId,
        );
      }
    });
  }

  /// Cambia la quantità di un oggetto già scelto. Con `copyWith` lo snapshot
  /// resta com'è, `isChecked` compreso.
  void _setQuantity(String itemId, int quantity) {
    final chosen = _items[itemId];
    if (chosen == null) return;
    setState(() => _items[itemId] = chosen.copyWith(quantity: quantity));
  }

  void _toggleLuggage(LuggageModel luggage) {
    setState(() {
      if (_luggages.containsKey(luggage.id)) {
        _luggages.remove(luggage.id);
      } else {
        _luggages[luggage.id] = luggage;
      }
    });
  }

  Future<void> _chooseHouse(List<HouseModel> houses, HouseModel current) async {
    final picked = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'create_sheet.choose_house'.tr(),
      items: houses,
      getLabel: (house) => house.displayName,
      getIcon: (house) => HouseIcons.getIcon(house.iconName),
      selected: current,
    );
    if (picked != null && mounted) {
      setState(() => _pickedHouseId = picked.id);
    }
  }

  Future<void> _save() async {
    final trip = _trip;
    if (trip == null || _saving) return;
    setState(() => _saving = true);

    // Normalizza gli oggetti legacy senza casa d'origine prima del salvataggio.
    final normalized = await _normalizeItemOrigins(_items.values.toList());
    if (!mounted) return;

    final updated = trip.copyWith(
      items: normalized,
      luggages: _luggages.values.toList(),
      updatedAt: DateTime.now(),
    );

    final saved = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(tripNotifierProvider.notifier).updateTrip(updated),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_trip_items_failed'.tr(),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }
    context.pop();
  }

  Future<void> _confirmDiscard() async {
    final leave = await DialogHelpers.showConfirmation(
      context: context,
      title: 'trips.pack.discard_title'.tr(),
      message: 'trips.pack.discard_message'.tr(),
      isDestructive: true,
    );
    if (leave && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final fetched = tripsAsync.valueOrNull
        ?.where((t) => t.id == widget.tripId)
        .firstOrNull;
    if (fetched != null) _hydrate(fetched);

    final placeholder = tripEditPlaceholder(
      context: context,
      ref: ref,
      title: 'trips.pack.title'.tr(),
      tripsAsync: tripsAsync,
      isHydrated: _trip != null,
    );
    if (placeholder != null) return placeholder;

    final trip = _trip!;
    final housesAsync = ref.watch(houseNotifierProvider);
    final houses = housesAsync.valueOrNull ?? const <HouseModel>[];
    final house = _houseFor(houses);
    final destinationHouseName = houses
        .where((h) => h.id == trip.destinationHouseId)
        .firstOrNull
        ?.displayName;
    final count = _items.length;

    return PopScope(
      // Con modifiche non salvate il back chiede conferma; durante il
      // salvataggio non fa nulla.
      canPop: !_saving && !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('trips.pack.title'.tr())),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.spacingMd,
                  context.spacingSm,
                  context.spacingMd,
                  context.spacingLg,
                ),
                children: [
                  if (widget.fromNewTrip)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.spacingMd),
                      child: DsSteps(
                        labels: [
                          'trips.new.step_trip'.tr(),
                          'trips.new.step_suitcase'.tr(),
                        ],
                        current: 1,
                      ),
                    ),
                  PackSummaryLine(
                    trip: trip,
                    destinationHouseName: destinationHouseName,
                    houseNames: {for (final h in houses) h.id: h.displayName},
                  ),
                  TripSectionTitle('trips.pack.luggages'.tr()),
                  _luggageSection(context, house),
                  TripSectionTitle('trips.pack.items'.tr()),
                  _itemsBlock(context, housesAsync),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacingMd,
                  context.spacingSm,
                  context.spacingMd,
                  context.spacingSm,
                ),
                child: DsButton(
                  label: count == 0
                      ? 'trips.pack.done'.tr()
                      : 'trips.pack.done_count'.plural(count),
                  icon: Icons.check,
                  expand: true,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _luggageSection(BuildContext context, HouseModel? house) {
    final luggagesAsync = ref.watch(allLuggagesProvider);

    return luggagesAsync.when(
      data: (luggages) {
        if (luggages.isEmpty) {
          return _noLuggages(context, house);
        }
        return Wrap(
          spacing: context.spacingSm,
          runSpacing: context.spacingSm,
          children: [
            for (final luggage in luggages)
              PackPill(
                label: luggage.name,
                icon: Icons.luggage_outlined,
                selected: _luggages.containsKey(luggage.id),
                onTap: () => _toggleLuggage(luggage),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DsErrorState(
        error: error,
        onRetry: () => ref.invalidate(allLuggagesProvider),
      ),
    );
  }

  Widget _noLuggages(BuildContext context, HouseModel? house) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'trips.pack.no_luggages'.tr(),
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        // I bagagli appartengono a una casa: senza casa non c'è dove crearli.
        if (house != null)
          DsLinkButton(
            label: 'trips.pack.add_luggages'.tr(),
            onPressed: () =>
                showLuggagesManagementSheet(context, houseId: house.id),
          ),
      ],
    );
  }

  Widget _itemsBlock(
    BuildContext context,
    AsyncValue<List<HouseModel>> housesAsync,
  ) {
    return housesAsync.when(
      data: (houses) {
        final house = _houseFor(houses);
        if (house == null) {
          return DsEmptyState(
            icon: Icons.home_outlined,
            title: 'items.no_houses_available'.tr(),
          );
        }
        return _housePanel(context, houses, house);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DsErrorState(
        error: error,
        onRetry: () => ref.invalidate(houseNotifierProvider),
      ),
    );
  }

  /// Ricerca, "Da" con la casa, e gli oggetti di quella casa.
  Widget _housePanel(
    BuildContext context,
    List<HouseModel> houses,
    HouseModel house,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final itemsAsync = ref.watch(itemNotifierProvider(house.id));
    final canChoose = houses.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'trips.pack.search_hint'.tr(),
            prefixIcon: Icon(
              Icons.search,
              size: context.iconSizeMd,
              color: cs.onSurfaceVariant,
            ),
            filled: true,
            fillColor: context.groupSurface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingMd,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: context.spacingMd),
        Row(
          children: [
            Text(
              'trips.pack.from'.tr(),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(width: context.spacingSm),
            Flexible(
              child: PackPill(
                label: house.displayName,
                icon: Icons.home_outlined,
                onTap: canChoose ? () => _chooseHouse(houses, house) : null,
              ),
            ),
            if (canChoose) ...[
              SizedBox(width: context.spacingXs),
              Icon(
                Icons.expand_more,
                size: context.iconSizeSm,
                color: cs.onSurfaceVariant,
              ),
            ],
          ],
        ),
        itemsAsync.when(
          data: (items) => _itemGroups(context, house, items),
          loading: () => Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacingLg),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => DsErrorState(
            error: error,
            onRetry: () => ref.invalidate(itemNotifierProvider(house.id)),
          ),
        ),
      ],
    );
  }

  /// Gli oggetti della casa divisi per categoria, in ordine canonico. Una casa
  /// senza oggetti offre di crearne; una ricerca senza esiti no.
  Widget _itemGroups(
    BuildContext context,
    HouseModel house,
    List<ItemModel> items,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: DsEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'common.no_items_in_house'.tr(),
          ctaLabel: 'create_sheet.ai_scan'.tr(),
          ctaIcon: Icons.auto_awesome,
          ctaKey: const Key('trip_items_empty_add'),
          onCta: () => startAiScan(context, ref, house.id),
          linkLabel: 'create_sheet.manual_link'.tr(),
          onLink: () => context.push('/houses/${house.id}?add=manual'),
        ),
      );
    }

    final visible = _query.isEmpty
        ? items
        : items.where((i) => i.name.toLowerCase().contains(_query)).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: Center(
          child: Text(
            'items.no_search_results'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final selection = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in ItemCategory.values)
          if (visible.any((item) => item.category == category)) ...[
            DsGroupHeader(
              label: category.displayName,
              count: visible.where((i) => i.category == category).length,
            ),
            Material(
              color: context.groupSurface,
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in visible.where(
                    (i) => i.category == category,
                  ))
                    PackItemRow(
                      item: item,
                      selected: selection[item.id],
                      onToggle: () => _toggleItem(item, house.id),
                      onQuantityChanged: (quantity) =>
                          _setQuantity(item.id, quantity),
                    ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}
