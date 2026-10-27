import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_icon_button.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_steps.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/view/item_sheet.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../luggages/model/luggage_model.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../../luggages/view/add_edit_luggage_screen.dart';
import '../../luggages/view/luggages_management_sheet.dart';
import '../model/ai_availability.dart';
import '../model/ai_packing.dart';
import '../model/pack_trip_request.dart';
import '../model/trip_model.dart';
import '../model/trip_postcard.dart';
import '../model/trip_weather.dart';
import '../providers/trip_provider.dart';
import 'ai_packing_wait_screen.dart';
import 'widgets/ai/ai_home_group.dart';
import 'widgets/ai/ai_pack_item_sheet.dart';
import 'widgets/ai/ai_pack_rows.dart';
import 'widgets/ai/ai_packing_sheet.dart';
import 'widgets/pack/pack_parts.dart';
import 'widgets/pack/pack_summary_line.dart';
import 'widgets/pack/pack_weather.dart';
import 'widgets/trip_edit_placeholder.dart';
import '../../../shared/widgets/ds_section_title.dart';
import '../../../shared/widgets/ds_search_field.dart';

/// Lettere della ricerca da cui, se ci sono risultati, compare anche la riga
/// "Aggiungi". Senza risultati compare subito.
const _kAddRowMinChars = 3;

/// Prepara la valigia di un viaggio: riepilogo, bagagli e oggetti.
///
/// È la stessa pagina per il passo 2 di "Nuovo viaggio" ([fromNewTrip]), per
/// "Modifica oggetti" e per la cartolina. Il salvataggio è esplicito, con
/// "Fatto": fino ad allora niente si scrive.
class PackSuitcaseScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// Passo 2 del nuovo viaggio: in cima si mostra l'indicatore dei passi.
  final bool fromNewTrip;

  /// Apre subito il foglio della valigia AI.
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

  /// Valigia generata dall'AI, presa dal viaggio. Se c'è, la pagina mostra
  /// solo i capi in valigia e la casa è quella della proposta.
  AiPackingResult? _aiResult;

  /// Oggetti del viaggio, per id. È la selezione: cambiare casa non la tocca.
  Map<String, TripItem> _items = {};
  Map<String, TripItem> _initialItems = {};

  /// Bagagli del viaggio, per id.
  Map<String, LuggageModel> _luggages = {};
  Map<String, LuggageModel> _initialLuggages = {};

  /// Valigia AI com'era all'apertura: confronto per "modificato".
  AiPackingResult? _initialAiResult;

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

  /// Copia il viaggio nello stato modificabile, una volta sola.
  ///
  /// Nessun `setState`: siamo dentro il build provocato da `ref.watch`.
  void _hydrate(TripModel trip) {
    if (_trip != null) return;
    _trip = trip;
    _aiResult = trip.aiResult;
    _initialAiResult = _aiResult;
    _items = {for (final item in trip.items) item.id: item};
    _initialItems = {..._items};
    _luggages = {for (final luggage in trip.luggages) luggage.id: luggage};
    _initialLuggages = {..._luggages};
  }

  /// Il viaggio com'è adesso nel provider. Le scritture partono da qui, non
  /// dalla copia presa all'apertura, che non ha le risposte salvate dopo.
  TripModel? _currentTrip() {
    final trips = ref.read(tripNotifierProvider).valueOrNull;
    return trips?.where((t) => t.id == widget.tripId).firstOrNull ?? _trip;
  }

  /// Vero se la selezione o i bagagli non sono più quelli di apertura.
  bool get _isDirty {
    final itemsChanged =
        _items.length != _initialItems.length ||
        _items.entries.any((entry) => _initialItems[entry.key] != entry.value);
    final luggagesChanged =
        _luggages.length != _initialLuggages.length ||
        _luggages.keys.any((id) => !_initialLuggages.containsKey(id));
    return itemsChanged || luggagesChanged || _aiResult != _initialAiResult;
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

  /// Cambia la quantità di un oggetto già scelto. Con `copyWith` lo snapshot
  /// resta com'è, `isChecked` compreso.
  void _setQuantity(String itemId, int quantity) {
    final chosen = _items[itemId];
    if (chosen == null) return;
    setState(() => _items[itemId] = chosen.copyWith(quantity: quantity));
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
    if (_aiResult != null) {
      setState(() => _query = created.name);
      _addToSuitcase(
        TripItem(
          id: created.id,
          name: created.name,
          category: created.category,
          quantity: created.quantity ?? 1,
          originHouseId: houseId,
        ),
      );
      return;
    }
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

  /// Mette in valigia un oggetto della casa (valigia generata) e lo dice con
  /// "Annulla", che lo toglie di nuovo.
  void _addToSuitcase(TripItem tripItem) {
    setState(() => _items[tripItem.id] = tripItem);
    AppSnackBar.showUndo(
      context,
      'trips.pack.ai.added'.tr(args: [tripItem.name]),
      onUndo: () {
        if (!mounted) return;
        setState(() => _items.remove(tripItem.id));
      },
    );
  }

  /// Toglie un capo dalla valigia generata. "Annulla" lo rimette allo stesso
  /// posto, con la stessa quantità.
  void _removeFromSuitcase(String itemId) {
    final removed = _items[itemId];
    if (removed == null) return;
    final index = _items.keys.toList().indexOf(itemId);
    setState(() => _items.remove(itemId));
    AppSnackBar.showUndo(
      context,
      'trips.pack.ai.removed'.tr(args: [removed.name]),
      onUndo: () {
        if (!mounted || _items.containsKey(removed.id)) return;
        setState(() => _items = _insertAt(_items, index, removed));
      },
    );
  }

  /// La scheda di un capo della valigia generata.
  Future<void> _openAiItem(
    TripItem tripItem,
    ItemModel item,
    AiPackedItem? proposed,
  ) => showAiPackItemSheet(
    context,
    item: _items[tripItem.id] ?? tripItem,
    available: item.quantity ?? 1,
    reason: proposed?.reason,
    inDeparture: proposed?.inDeparture ?? false,
    onQuantity: (quantity) => _setQuantity(tripItem.id, quantity),
    onRemove: () => _removeFromSuitcase(tripItem.id),
  );

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

    final updated = (_currentTrip() ?? trip).copyWith(
      items: normalized,
      luggages: _luggages.values.toList(),
      aiResult: _aiResult,
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

  /// Scrive la ricerca dall'avviso ("Cerca nell'armadio").
  void _searchFrom(String text) {
    _searchController.text = text;
    setState(() => _query = text.trim());
  }

  /// "Ok, capito": l'avviso esce dalla lista; si salva con "Fatto".
  void _dismissWarning(String id) {
    final result = _aiResult;
    if (result == null || result.dismissedWarnings.contains(id)) return;
    setState(() {
      _aiResult = result.copyWith(
        dismissedWarnings: [...result.dismissedWarnings, id],
      );
    });
  }

  /// Il tocco sull'icona AI: se la valigia ha già capi chiede conferma, poi
  /// apre il foglio e la pagina d'attesa. Senza coordinate dice il motivo.
  Future<void> _onAiTap() async {
    final trip = _currentTrip();
    if (trip == null || _saving) return;
    final houses =
        ref.read(houseNotifierProvider).valueOrNull ?? const <HouseModel>[];
    final availability = aiAvailabilityOf(
      trip,
      houses: houses,
      today: DateTime.now(),
    );
    switch (availability) {
      case AiUnavailable(:final messageKey):
        AppSnackBar.showInfo(context, messageKey.tr());
      case AiAvailable(:final plan):
        await _prepareAi(trip, plan);
    }
  }

  Future<void> _prepareAi(TripModel trip, TripWeatherRequest plan) async {
    if (_items.isNotEmpty) {
      final replace = await DialogHelpers.showConfirmation(
        context: context,
        title: 'trips.pack.ai.replace_title'.tr(),
        message: 'trips.pack.ai.replace_message'.tr(),
        confirmLabel: 'trips.pack.ai.replace_confirm'.tr(),
        isDestructive: true,
      );
      if (!replace || !mounted) return;
    }

    final setup = await showAiPackingSheet(context, trip: trip, plan: plan);
    if (setup == null || !mounted) return;
    final houseId = setup.houseId;
    if (houseId == null) return;

    // Le risposte si salvano subito: "Rigenera" non le chiede di nuovo.
    final current = _currentTrip() ?? trip;
    final saved = await _writeTrip(
      current.copyWith(aiSetup: setup, updatedAt: DateTime.now()),
    );
    if (!saved || !mounted) return;

    final luggage = _luggageById(setup.luggageId);
    final names = [for (final stop in aiStopsOf(plan)) stop.name];
    final result = await context.push<AiPackingResult>(
      '/trips/${trip.id}/ai-packing',
      extra: PackTripJob(
        body: packTripBody(
          plan: plan,
          setup: setup,
          houseId: houseId,
          luggage: luggage,
        ),
        houseId: houseId,
        title: _joinStops(names),
        nights: nightsBetween(trip.departureDateTime, trip.returnDateTime) ?? 0,
      ),
    );
    if (result == null || !mounted) return;
    await _adoptResult(result, setup: setup, luggage: luggage);
  }

  /// La proposta diventa la valigia: oggetti e bagaglio, e si salva subito con
  /// le risposte. Un oggetto non più in casa viene saltato. Se gli oggetti
  /// della casa non si leggono, la proposta si salva lo stesso, con i capi e i
  /// bagagli com'erano.
  Future<void> _adoptResult(
    AiPackingResult result, {
    required AiPackingSetup setup,
    LuggageModel? luggage,
  }) async {
    final trip = _currentTrip();
    if (trip == null) return;

    Map<String, TripItem>? proposed;
    try {
      final houseItems = await ref.read(
        itemNotifierProvider(result.houseId).future,
      );
      if (!mounted) return;
      proposed = _proposedItems(result, houseItems);
    } catch (_) {
      if (!mounted) return;
    }

    final items = proposed ?? _items;
    final luggages = luggage == null || proposed == null
        ? {..._luggages}
        : {luggage.id: luggage};

    final saved = await _writeTrip(
      trip.copyWith(
        items: items.values.toList(),
        luggages: luggages.values.toList(),
        aiSetup: setup,
        aiResult: result,
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    // "La proposta è salva" si dice solo se la scrittura è riuscita.
    if (!saved) {
      AppSnackBar.showError(context, 'errors.save_error'.tr());
    } else if (proposed == null) {
      AppSnackBar.showError(context, 'trips.pack.ai.items_error'.tr());
    }
    setState(() {
      _aiResult = result;
      _items = {...items};
      _luggages = luggages;
      // Senza salvataggio riuscito la pagina resta modificata: "Fatto" riprova.
      if (saved) {
        _initialItems = {...items};
        _initialLuggages = {...luggages};
        _initialAiResult = result;
      }
    });
  }

  /// I capi della proposta, con nome e categoria dell'oggetto di casa. Un
  /// oggetto non più in casa non entra; la quantità sta tra 1 e i pezzi
  /// salvati (senza quantità salvata, 1).
  Map<String, TripItem> _proposedItems(
    AiPackingResult result,
    List<ItemModel> houseItems,
  ) {
    final byId = {for (final item in houseItems) item.id: item};
    final items = <String, TripItem>{};
    for (final proposed in result.proposal) {
      final item = byId[proposed.itemId];
      if (item == null) continue;
      final available = item.quantity ?? 1;
      final cap = available < 1 ? 1 : available;
      final quantity = proposed.quantity < 1
          ? 1
          : (proposed.quantity > cap ? cap : proposed.quantity);
      items[item.id] = TripItem(
        id: item.id,
        name: item.name,
        category: item.category,
        quantity: quantity,
        originHouseId: result.houseId,
      );
    }
    return items;
  }

  Future<bool> _writeTrip(TripModel trip) => ErrorRetryDialog.executeWithRetry(
    context: context,
    operation: () => ref.read(tripNotifierProvider.notifier).updateTrip(trip),
    errorTitle: 'errors.save_error'.tr(),
    errorMessage: 'errors.save_trip_items_failed'.tr(),
  );

  LuggageModel? _luggageById(String? id) {
    if (id == null) return null;
    final luggages =
        ref.read(luggageNotifierProvider).valueOrNull ?? const <LuggageModel>[];
    return luggages.where((l) => l.id == id).firstOrNull;
  }

  /// "Islanda e Olanda", "Islanda, Olanda e Francia".
  String _joinStops(List<String> names) {
    if (names.length <= 1) return names.join();
    return 'trips.pack.ai.stops_join'.tr(
      args: [names.sublist(0, names.length - 1).join(', '), names.last],
    );
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
    final destinationHouseName = houses
        .where((h) => h.id == trip.destinationHouseId)
        .firstOrNull
        ?.displayName;
    final count = _items.length;
    final aiAvailable =
        aiAvailabilityOf(trip, houses: houses, today: DateTime.now())
            is AiAvailable;
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
        appBar: AppBar(
          title: Text('trips.pack.title'.tr()),
          actions: [
            // Grigia se la valigia AI non si può chiedere: il tocco dice perché.
            DsIconButton(
              key: const Key('pack_ai_suitcase'),
              tooltip: _aiResult == null
                  ? 'trips.pack.ai.prepare_button'.tr()
                  : 'trips.pack.ai.regenerate'.tr(),
              icon: Icons.auto_awesome_outlined,
              color: aiAvailable
                  ? null
                  : Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: AppOpacity.disabled,
                    ),
              onPressed: _onAiTap,
            ),
          ],
        ),
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
              PackSummaryLine(
                trip: trip,
                destinationHouseName: destinationHouseName,
                houseNames: {for (final h in houses) h.id: h.displayName},
              ),
              if (_aiResult case final result?) ...[
                SizedBox(height: context.spacingMd),
                AiPackRows(
                  warnings: result.openWarnings,
                  reasons: result.reasons,
                  onSearch: _searchFrom,
                  onDismiss: _dismissWarning,
                ),
              ],
              PackWeatherSection(trip: trip),
              DsSectionTitle('trips.pack.luggages'.tr()),
              _luggageSection(context),
              DsSectionTitle('trips.pack.items'.tr()),
              _itemsBlock(context, housesAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _luggageSection(BuildContext context) {
    final luggagesAsync = ref.watch(luggageNotifierProvider);

    return luggagesAsync.when(
      data: (luggages) {
        if (luggages.isEmpty) {
          return _noLuggages(context);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
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
            ),
            // Con dei bagagli si crea da "Gestisci bagagli"; il link "Nuovo
            // bagaglio" resta solo quando non ce n'è nessuno.
            DsLinkButton(
              key: const Key('pack_manage_luggages'),
              icon: Icons.edit_outlined,
              label: 'luggages.manage'.tr(),
              onPressed: () async {
                final before = {for (final l in luggages) l.id};
                await showLuggagesManagementSheet(context);
                if (!mounted) return;
                final current = ref.read(luggageNotifierProvider).valueOrNull;
                if (current == null) return;
                // Quelli creati nel foglio entrano nel viaggio, come faceva il
                // link "Nuovo bagaglio".
                setState(() {
                  _luggages = {
                    for (final l in current)
                      if (_luggages.containsKey(l.id) || !before.contains(l.id))
                        l.id: l,
                  };
                });
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DsErrorState(
        error: error,
        title: 'luggages.load_failed'.tr(),
        onRetry: () => ref.invalidate(luggageNotifierProvider),
      ),
    );
  }

  Widget _noLuggages(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'trips.pack.no_luggages'.tr(),
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        _newLuggageLink(),
      ],
    );
  }

  Widget _newLuggageLink() => DsLinkButton(
    key: const Key('pack_new_luggage'),
    icon: Icons.add,
    label: 'luggages.add_new'.tr(),
    onPressed: () async {
      final created = await showAddEditLuggageSheet(context);
      if (created != null && mounted) {
        setState(() => _luggages[created.id] = created);
      }
    },
  );

  Widget _itemsBlock(
    BuildContext context,
    AsyncValue<List<HouseModel>> housesAsync,
  ) {
    final result = _aiResult;
    if (result != null) return _aiItemsBlock(context, housesAsync, result);
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

  /// Valigia generata: la casa è quella della proposta, la lista mostra solo i
  /// capi in valigia, e in fondo ci sono "Dalla casa" e la ricerca.
  Widget _aiItemsBlock(
    BuildContext context,
    AsyncValue<List<HouseModel>> housesAsync,
    AiPackingResult result,
  ) {
    final itemsAsync = ref.watch(itemNotifierProvider(result.houseId));
    final houses = housesAsync.valueOrNull ?? const <HouseModel>[];

    return itemsAsync.when(
      data: (items) => _aiPanel(context, result, houses, items),
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => DsErrorState(
        error: error,
        onRetry: () => ref.invalidate(itemNotifierProvider(result.houseId)),
      ),
    );
  }

  Widget _aiPanel(
    BuildContext context,
    AiPackingResult result,
    List<HouseModel> houses,
    List<ItemModel> houseItems,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final houseName =
        houses.where((h) => h.id == result.houseId).firstOrNull?.displayName ??
        '';
    final byId = {for (final item in houseItems) item.id: item};
    final proposal = {for (final p in result.proposal) p.itemId: p};
    final query = _query.toLowerCase();
    final packed = _items.values.toList();

    // Ricerca: gli oggetti della casa che non sono in valigia.
    final results = query.isEmpty
        ? const <ItemModel>[]
        : houseItems
              .where(
                (i) =>
                    !_items.containsKey(i.id) &&
                    i.name.toLowerCase().contains(query),
              )
              .toList();
    // Come la pagina manuale: senza risultati la riga compare subito; con
    // risultati, da [_kAddRowMinChars] lettere, e mai se il nome esiste già.
    final hasExact =
        query.isNotEmpty &&
        houseItems.any((i) => i.name.trim().toLowerCase() == query);
    final showAddRow =
        query.isNotEmpty &&
        !hasExact &&
        (results.isEmpty || query.length >= _kAddRowMinChars);

    final home = houseItems
        .where(
          (i) =>
              i.category != ItemCategory.vestiti && !_items.containsKey(i.id),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: context.spacingXs),
              child: Icon(
                Icons.info_outline,
                size: context.iconSizeSm,
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Text(
                'trips.pack.ai.note'.tr(),
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacingMd),
        _searchField(context, hint: 'trips.pack.ai.search_hint'.tr()),
        if (query.isNotEmpty) ...[
          SizedBox(height: context.spacingMd),
          if (results.isNotEmpty)
            Material(
              color: context.groupSurface,
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in results)
                    AiWardrobeRow(
                      key: Key('pack_ai_result_${item.id}'),
                      name: item.name,
                      subtitle: item.category.displayName,
                      onAdd: () => _addToSuitcase(
                        TripItem(
                          id: item.id,
                          name: item.name,
                          category: item.category,
                          quantity: 1,
                          originHouseId: result.houseId,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (results.isNotEmpty && showAddRow)
            SizedBox(height: context.spacingMd),
          if (showAddRow)
            PackAddRow(
              key: const Key('pack_add_row'),
              name: _query,
              houseName: houseName,
              onTap: () => _createInHouse(result.houseId, houseName),
            ),
        ],
        if (packed.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacingMd),
            child: Text(
              'trips.pack.ai.suitcase_empty'.tr(),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        for (final category in ItemCategory.values)
          if (packed.any((tripItem) => tripItem.category == category)) ...[
            DsGroupHeader(
              label: category.displayName,
              count: packed.where((t) => t.category == category).length,
            ),
            Material(
              color: context.groupSurface,
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final tripItem in packed.where(
                    (t) => t.category == category,
                  ))
                    PackItemRow(
                      packedOnly: true,
                      item: byId[tripItem.id],
                      selected: tripItem,
                      inDeparture: proposal[tripItem.id]?.inDeparture ?? false,
                      onRemove: () => _removeFromSuitcase(tripItem.id),
                      onOpen: byId[tripItem.id] == null
                          ? null
                          : () => _openAiItem(
                              tripItem,
                              byId[tripItem.id]!,
                              proposal[tripItem.id],
                            ),
                      onQuantityChanged: (quantity) =>
                          _setQuantity(tripItem.id, quantity),
                    ),
                ],
              ),
            ),
          ],
        if (home.isNotEmpty) ...[
          SizedBox(height: context.spacingLg),
          AiHomeGroup(
            items: home,
            onAdd: (item) => _addToSuitcase(
              TripItem(
                id: item.id,
                name: item.name,
                category: item.category,
                quantity: 1,
                originHouseId: result.houseId,
              ),
            ),
          ),
        ],
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

/// [items] con [item] rimesso alla posizione [index], come era prima di
/// essere tolto.
Map<String, TripItem> _insertAt(
  Map<String, TripItem> items,
  int index,
  TripItem item,
) {
  final entries = items.entries.toList()
    ..insert(index.clamp(0, items.length), MapEntry(item.id, item));
  return {for (final entry in entries) entry.key: entry.value};
}
