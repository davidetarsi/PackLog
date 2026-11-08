import 'dart:async';

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
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_steps.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/view/item_sheet.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../model/ai_availability.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/ai_packing_launcher.dart';
import 'widgets/pack/pack_parts.dart';
import 'widgets/trip_edit_placeholder.dart';
import '../../../shared/widgets/ds_section_title.dart';
import '../../../shared/widgets/ds_search_field.dart';

/// Lettere della ricerca manuale da cui compare anche la riga "Aggiungi".
const _kAddRowMinChars = 3;

/// Aggiunge oggetti della casa alla valigia di un viaggio: ricerca, casa e
/// oggetti da spuntare. Riepilogo, meteo e bagagli stanno nel dettaglio.
///
/// È la stessa pagina per il passo 2 di "Nuovo viaggio" ([fromNewTrip]) e per
/// "Aggiungi oggetti" dal dettaglio. Il salvataggio è esplicito, con "Fatto":
/// fino ad allora niente si scrive.
class PackSuitcaseScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// Passo 2 del nuovo viaggio: in cima si mostra l'indicatore dei passi.
  final bool fromNewTrip;

  /// Apre subito il foglio della valigia AI (`?ai=1`, "Rigenera" dal menu).
  final bool startAi;

  const PackSuitcaseScreen({
    super.key,
    required this.tripId,
    this.fromNewTrip = false,
    this.startAi = false,
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

  /// Casa scelta dal selettore; `null` finché non se ne sceglie una.
  String? _pickedHouseId;

  /// Il tocco automatico di [PackSuitcaseScreen.startAi] è già partito.
  bool _startAiScheduled = false;

  /// Campo della ricerca: dopo un'aggiunta ci si scrive il nome creato.
  final _searchController = TextEditingController();

  /// Testo della ricerca, senza spazi ai lati.
  String _query = '';

  /// Vero mentre il viaggio si salva: il bottone resta del suo colore.
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Dal nuovo viaggio è il passo 2; dal dettaglio è "Aggiungi alla valigia".
  String get _title => widget.fromNewTrip
      ? 'trips.pack.title'.tr()
      : 'trips.pack.add_title'.tr();

  /// Copia il viaggio nello stato modificabile, una volta sola.
  ///
  /// Nessun `setState`: siamo dentro il build provocato da `ref.watch`.
  void _hydrate(TripModel trip) {
    if (_trip != null) return;
    _trip = trip;
    _items = {for (final item in trip.items) item.id: item};
    _initialItems = {..._items};
  }

  /// Il viaggio com'è adesso nel provider. Le scritture partono da qui, non
  /// dalla copia presa all'apertura, che non ha le risposte salvate dopo.
  TripModel? _currentTrip() {
    final trips = ref.read(tripNotifierProvider).valueOrNull;
    return trips?.where((t) => t.id == widget.tripId).firstOrNull ?? _trip;
  }

  /// Vero se la selezione non è più quella di apertura.
  bool get _isDirty {
    return _items.length != _initialItems.length ||
        _items.entries.any((entry) => _initialItems[entry.key] != entry.value);
  }

  /// La casa mostrata in "Cosa porti": quella scelta, altrimenti la proposta.
  HouseModel? _houseFor(List<HouseModel> houses) {
    final picked = _pickedHouseId;
    if (picked != null) {
      for (final house in houses) {
        if (house.id == picked) return house;
      }
    }
    final trip = _trip;
    if (trip == null) return defaultDestinationHouse(houses);
    return proposedPackingHouse(houses, trip);
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

  /// Cambiare quantità aggiungendo copie richiede di confermare di nuovo la
  /// spunta; una riduzione conserva la spunta esistente.
  void _setQuantity(String itemId, int quantity) {
    final chosen = _items[itemId];
    if (chosen == null) return;
    setState(
      () => _items[itemId] = chosen.copyWith(
        quantity: quantity,
        isChecked: quantity > chosen.quantity ? false : chosen.isChecked,
      ),
    );
  }

  /// Crea nella casa l'oggetto cercato e lo mette in valigia. La ricerca
  /// passa al nome creato, così l'oggetto si vede già scelto.
  Future<void> _createInHouse(String houseId, String houseName) async {
    final created = await showNewItemSheet(
      context,
      houseId: houseId,
      initialName: _query,
      submitLabel: 'trips.pack.add_and_pack'.tr(),
      submitIcon: Icons.luggage_outlined,
      footnote: 'trips.pack.also_in_house'.tr(args: [houseName]),
    );
    if (created == null || !mounted) return;
    _searchController.text = created.name;
    setState(() {
      _query = created.name;
      _items[created.id] = TripItem(
        id: created.id,
        name: created.name,
        category: created.category,
        quantity: created.quantity ?? 1,
        originHouseId: houseId,
      );
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

    final updated = (_currentTrip() ?? trip).copyWith(
      items: normalized,
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
    // Dal nuovo viaggio il passo 2 lascia il posto al dettaglio; altrimenti si
    // torna alla pagina che ha aperto l'aggiunta.
    if (widget.fromNewTrip) {
      context.pushReplacement('/trips/${widget.tripId}');
    } else {
      context.pop();
    }
  }

  /// Apertura con `?ai=1` ("Rigenera" dal dettaglio): il lanciatore condiviso
  /// chiede conferma, apre il foglio e la pagina d'attesa. La valigia arriva e
  /// si salva fuori da qui.
  Future<void> _onAiTap() async {
    final trip = _currentTrip();
    if (trip == null || _saving) return;
    await startAiPacking(
      context,
      ref,
      // Gli oggetti sono quelli della pagina, anche non ancora salvati.
      trip: trip.copyWith(items: _items.values.toList()),
      isNew: false,
      // La pagina si chiude prima dell'attesa: la sua copia della valigia è
      // vecchia e non deve poter riscrivere quella nuova.
      beforeWait: () => context.canPop()
          ? context.pop()
          : context.go('/trips/${widget.tripId}'),
    );
  }

  Future<void> _confirmDiscard() async {
    final leave = await DialogHelpers.showConfirmation(
      context: context,
      title: 'trips.pack.discard_title'.tr(),
      // Con una valigia AI già salvata si perde solo quello fatto dopo.
      message:
          (_trip?.aiResult == null
                  ? 'trips.pack.discard_message'
                  : 'trips.pack.ai.discard_message')
              .tr(),
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
      title: _title,
      tripsAsync: tripsAsync,
      isHydrated: _trip != null,
    );
    if (placeholder != null) return placeholder;

    final housesAsync = ref.watch(houseNotifierProvider);
    final count = _items.length;
    if (widget.startAi && !_startAiScheduled) {
      _startAiScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_onAiTap());
      });
    }

    return PopScope(
      // Con modifiche non salvate il back chiede conferma; durante il
      // salvataggio non fa nulla.
      canPop: !_saving && !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _confirmDiscard();
      },
      child: StickyCtaScaffold(
        appBar: AppBar(title: Text(_title)),
        bottomContent: DsButton(
          label: count == 0
              ? 'trips.pack.done'.tr()
              : 'trips.pack.done_count'.plural(count),
          icon: Icons.check,
          expand: true,
          isLoading: _saving,
          onPressed: _save,
        ),
        body: Builder(
          builder: (context) => ListView(
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingSm,
              context.spacingMd,
              context.spacingLg + context.ctaReservedHeight,
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
              DsSectionTitle('trips.pack.items'.tr()),
              _itemsBlock(context, housesAsync),
            ],
          ),
        ),
      ),
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
        title: 'errors.load_houses'.tr(),
        onRetry: () => ref.invalidate(houseNotifierProvider),
      ),
    );
  }

  /// Campo della ricerca, uguale nelle due modalità.
  Widget _searchField(BuildContext context, {required String hint}) {
    // La x svuota e chiama onChanged(''): la lista torna intera.
    return DsSearchField(
      controller: _searchController,
      hintText: hint,
      onChanged: (value) => setState(() => _query = value.trim()),
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
        _searchField(context, hint: 'trips.pack.search_hint'.tr()),
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
            title: 'errors.load_items'.tr(),
            onRetry: () => ref.invalidate(itemNotifierProvider(house.id)),
          ),
        ),
      ],
    );
  }

  /// Gli oggetti della casa divisi per categoria, in ordine canonico.
  ///
  /// Con una ricerca la riga "Aggiungi «nome»" crea l'oggetto che manca: da
  /// sola se non c'è nessun risultato, in fondo se ci sono risultati ma
  /// nessuno con quel nome esatto (da [_kAddRowMinChars] lettere).
  Widget _itemGroups(
    BuildContext context,
    HouseModel house,
    List<ItemModel> items,
  ) {
    final query = _query.toLowerCase();
    final addRow = PackAddRow(
      key: const Key('pack_add_row'),
      name: _query,
      houseName: house.displayName,
      onTap: () => _createInHouse(house.id, house.displayName),
    );

    if (items.isEmpty && query.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        // Qui si sceglie cosa portare, non si riempie la casa: niente
        // scansione né pagina "Aggiungi". Un oggetto che manca si crea dalla
        // ricerca, senza uscire dalla valigia.
        child: DsEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'common.no_items_in_house'.tr(),
          subtitle: 'trips.pack.empty_house_hint'.tr(),
        ),
      );
    }

    final visible = query.isEmpty
        ? items
        : items.where((i) => i.name.toLowerCase().contains(query)).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: context.spacingMd),
        child: addRow,
      );
    }
    // Sotto i risultati la riga compare da qualche lettera in su: con una o
    // due si sta ancora cercando, non scrivendo il nome di un oggetto nuovo.
    final showAddRow =
        query.length >= _kAddRowMinChars &&
        !items.any((i) => i.name.trim().toLowerCase() == query);

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
        if (showAddRow) ...[SizedBox(height: context.spacingMd), addRow],
      ],
    );
  }
}
