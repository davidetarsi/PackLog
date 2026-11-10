import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/dialog_helpers.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_error_state.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_field_label.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../ai_input/helpers/ai_item_category.dart';
import '../../ai_input/model/clothing_analysis_result.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../../spaces/view/add_edit_space_screen.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../model/clothing_details.dart';
import '../model/item_metadata_merge.dart';
import '../model/item_model.dart';
import '../providers/item_enrichment_provider.dart';
import '../providers/item_provider.dart';
import '../services/category_infer_service.dart';
import '../widgets/category_pill.dart';
import 'bulk_move_sheet.dart';
import 'widgets/clothing_details_section.dart';
import '../../../shared/widgets/ds_divider.dart';

/// Apre la scheda di un oggetto esistente.
Future<void> showItemSheet(
  BuildContext context, {
  required String houseId,
  required String itemId,
}) {
  return showDsFormSheet(
    context,
    builder: (_) => ItemSheet(houseId: houseId, itemId: itemId),
  );
}

/// Apre la scheda per creare un oggetto nella casa [houseId], con il nome già
/// scritto ([initialName]). Restituisce l'oggetto creato, o `null` se la
/// scheda si chiude senza crearlo.
Future<ItemModel?> showNewItemSheet(
  BuildContext context, {
  required String houseId,
  String initialName = '',
  required String submitLabel,
  IconData? submitIcon,
  String? footnote,
}) {
  return showDsFormSheet<ItemModel>(
    context,
    builder: (_) => ItemSheet.create(
      houseId: houseId,
      initialName: initialName,
      submitLabel: submitLabel,
      submitIcon: submitIcon,
      footnote: footnote,
    ),
  );
}

/// Apre la scheda di un capo della scansione non ancora salvato. Restituisce
/// il capo modificato, o `null` se la scheda si chiude senza salvare.
Future<ClothingAnalysisResult?> showScanItemSheet(
  BuildContext context, {
  required ClothingAnalysisResult result,
}) {
  return showDsFormSheet<ClothingAnalysisResult>(
    context,
    builder: (_) => ItemSheet.scan(result: result),
  );
}

/// Opzione del picker spazio. `id == null` è "Senza spazio": non si può
/// usare `null` come valore, per [DsPickerSheet] vuol dire "chiuso".
typedef _SpaceOption = ({String? id, String name, IconData icon});

enum _ItemMenu { move, delete }

/// Scheda di un oggetto, la stessa per crearlo e per modificarlo: nome,
/// categorie su una riga, quantità, spazio (se la casa ne ha) e dettagli.
///
/// Le categorie sono le pillole della pagina "Aggiungi" della casa: bordata è
/// la proposta dedotta dal nome, piena la scelta dell'utente. Nella modifica
/// la categoria dell'oggetto è già una scelta. Spostare in un'altra casa ed
/// eliminare stanno nel "⋮", solo nella modifica.
///
/// Dalla scansione ([ItemSheet.scan]) la scheda modifica un capo non ancora
/// salvato: nome, categoria e dettagli, senza casa né menu. Non scrive nel DB:
/// chiude restituendo il capo modificato.
class ItemSheet extends ConsumerStatefulWidget {
  final String houseId;

  /// Oggetto da modificare; `null` per crearne uno.
  final String? itemId;

  /// Nome con cui parte la creazione.
  final String initialName;

  /// Etichetta e icona del bottone della creazione.
  final String? submitLabel;
  final IconData? submitIcon;

  /// Riga di aiuto sopra il bottone della creazione.
  final String? footnote;

  /// Il capo della scansione da modificare; `null` fuori dalla scansione.
  final ClothingAnalysisResult? scanResult;

  const ItemSheet({
    super.key,
    required this.houseId,
    required String this.itemId,
  }) : initialName = '',
       submitLabel = null,
       submitIcon = null,
       footnote = null,
       scanResult = null;

  const ItemSheet.create({
    super.key,
    required this.houseId,
    this.initialName = '',
    required String this.submitLabel,
    this.submitIcon,
    this.footnote,
  }) : itemId = null,
       scanResult = null;

  /// Senza casa: la scheda della scansione non legge né scrive gli oggetti.
  /// [houseId] è vuoto e non si usa.
  const ItemSheet.scan({super.key, required ClothingAnalysisResult result})
    : houseId = '',
      itemId = null,
      initialName = '',
      submitLabel = null,
      submitIcon = null,
      footnote = null,
      scanResult = result;

  @override
  ConsumerState<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<ItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  /// Categoria scelta toccando una pillola. Nella creazione, finché è `null`,
  /// vale quella dedotta dal nome.
  ItemCategory? _chosenCategory;
  int _quantity = 1;
  String? _spaceId;

  /// Dettagli del capo: come sono salvati (si aggiornano quando arrivano
  /// metadati nuovi) e come li vede l'utente. Null se per un oggetto che l'AI
  /// ha riconosciuto come non capo.
  ClothingDetails? _originalDetails;
  ClothingDetails? _details;

  /// I campi che l'utente ha toccato in questa scheda, anche senza cambiarli:
  /// al salvataggio diventano sue scelte, e l'AI non le cambia più.
  final Set<ClothingField> _touched = {};

  /// I metadati già letti: quando cambiano (la risposta dell'AI) i campi che
  /// l'utente non ha toccato si aggiornano.
  String? _seenMetadata;

  /// I metadati com'erano quando la scheda si è aperta: servono a sapere, se
  /// l'utente rinomina, se la scheda dell'AI è per il nome vecchio.
  String? _openedMetadata;

  /// Se l'utente ha toccato una categoria. Finché no, la categoria segue
  /// l'oggetto, perché l'AI può cambiarla.
  bool _categoryTouched = false;

  /// Solo dalla scansione: i dubbi del server ancora da risolvere, e la
  /// categoria di partenza.
  Set<String> _doubts = {};
  ItemCategory? _scanCategory;

  bool _loaded = false;
  bool _isSaving = false;

  bool get _isScan => widget.scanResult != null;

  bool get _isNew => widget.itemId == null && !_isScan;

  /// In modifica: qualcosa è diverso dall'oggetto salvato. Nella scansione:
  /// qualcosa è diverso dal capo ricevuto.
  bool get _isDirty {
    if (_isScan) return _scanDirty();
    final item = _item();
    if (item == null) return false;
    final note = _noteController.text.trim();
    return _nameController.text.trim() != item.name ||
        note != (item.description ?? '') ||
        (_chosenCategory ?? item.category) != item.category ||
        _quantity != (item.quantity ?? 1) ||
        _spaceId != item.spaceId ||
        (_details != null && _details != _originalDetails) ||
        _hasUnsavedTouches(item) ||
        (_categoryTouched &&
            !userFieldsOf(item.aiMetadata).contains(kUserCategoryField));
  }

  /// Un campo toccato che i metadati non segnano ancora come scelta dell'utente:
  /// toccarlo e salvare lo deve salvare, anche se il valore è lo stesso.
  bool _hasUnsavedTouches(ItemModel item) {
    final userFields = userFieldsOf(item.aiMetadata);
    return _touched.any((field) => !userFields.contains(metadataKeyOf(field)));
  }

  /// Anche un dubbio risolto conta: confermare il valore proposto toglie il
  /// "da controllare", e quel cambiamento va salvato.
  bool _scanDirty() {
    final result = widget.scanResult!;
    return _nameController.text.trim() != result.name ||
        _chosenCategory != _scanCategory ||
        (_details != null && _details != _originalDetails) ||
        _doubts.length != result.doubts.toSet().length;
  }

  /// La categoria che la scheda mostra adesso: scelta, della scansione, dedotta
  /// dal nome ([inferred], nuovo oggetto) o dell'oggetto salvato.
  ItemCategory? _currentCategory(ItemCategory? inferred) =>
      _chosenCategory ?? _scanCategory ?? inferred ?? _item()?.category;

  /// I dettagli da mostrare per [category]: cambiano subito se l'utente sceglie
  /// un'altra categoria. I valori nascosti restano.
  Set<ClothingField> _fieldsFor(
    ClothingDetails? details,
    ItemCategory? category,
  ) {
    if (category == null || details == null) return const {};
    return clothingFieldsFor(category, details.subCategory ?? '');
  }

  ItemModel? _item() =>
      (ref.read(itemNotifierProvider(widget.houseId)).valueOrNull ??
              const <ItemModel>[])
          .where((i) => i.id == widget.itemId)
          .firstOrNull;

  @override
  void initState() {
    super.initState();
    if (_isScan) {
      _initScan(widget.scanResult!);
      return;
    }
    if (_isNew) {
      _nameController.text = widget.initialName;
      _details = ClothingDetails.empty;
      _loaded = true;
      return;
    }
  }

  void _hydrate(ItemModel item) {
    if (_loaded) return;
    _nameController.text = item.name;
    _noteController.text = item.description ?? '';
    _chosenCategory = item.category;
    _quantity = item.quantity ?? 1;
    _spaceId = item.spaceId;
    _seenMetadata = item.aiMetadata;
    _openedMetadata = item.aiMetadata;
    _originalDetails = _detailsOf(item.aiMetadata);
    _details = _originalDetails;
    _loaded = true;
  }

  /// In modifica, quando i metadati cambiano (la risposta dell'AI), i campi che
  /// l'utente non ha toccato prendono i valori nuovi; quelli toccati restano.
  /// Anche la categoria segue l'oggetto, finché l'utente non ne tocca una.
  void _refreshFrom(ItemModel item) {
    if (item.aiMetadata == _seenMetadata) return;
    _seenMetadata = item.aiMetadata;
    final stored = _detailsOf(item.aiMetadata);
    final shown = _details;
    _originalDetails = stored;
    _details = stored == null || shown == null
        ? stored
        : _keepTouched(stored, shown);
    if (!_categoryTouched) _chosenCategory = item.category;
  }

  /// [stored] con i campi toccati presi da [shown].
  ClothingDetails _keepTouched(ClothingDetails stored, ClothingDetails shown) {
    bool touched(ClothingField field) => _touched.contains(field);
    return ClothingDetails(
      subCategory: touched(ClothingField.type)
          ? shown.subCategory
          : stored.subCategory,
      color: touched(ClothingField.color) ? shown.color : stored.color,
      warmth: touched(ClothingField.warmth) ? shown.warmth : stored.warmth,
      waterResistance: touched(ClothingField.waterResistance)
          ? shown.waterResistance
          : stored.waterResistance,
      formality: touched(ClothingField.formality)
          ? shown.formality
          : stored.formality,
      uses: touched(ClothingField.uses) ? shown.uses : stored.uses,
    );
  }

  /// Dalla scansione: nome, categoria e dettagli del capo ricevuto. I dettagli
  /// si mostrano solo per un capo di abbigliamento.
  void _initScan(ClothingAnalysisResult result) {
    _nameController.text = result.name;
    _scanCategory = aiItemCategory(
      result.category,
      appCategory: result.appCategory,
    );
    _chosenCategory = _scanCategory;
    _doubts = {...result.doubts};
    if (result.category != 'Not Clothing') {
      _originalDetails = ClothingDetails.of(result);
      _details = _originalDetails;
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Categoria dedotta dal nome, solo nella creazione e finché l'utente non
  /// ne sceglie una. [service] è `null` finché il dizionario non è pronto.
  ItemCategory? _inferredCategory(CategoryInferService? service) {
    final name = _nameController.text.trim();
    // Senza nome non si propone niente, come nella pagina "Aggiungi".
    if (!_isNew || _chosenCategory != null || name.isEmpty) return null;
    return service?.infer(name).category;
  }

  /// Nella creazione, toccare la pillola già scelta torna alla proposta, come
  /// nella pagina "Aggiungi". Nella modifica una categoria c'è sempre.
  void _tapCategory(ItemCategory category) {
    setState(() {
      _categoryTouched = true;
      _chosenCategory = _isNew && _chosenCategory == category ? null : category;
    });
  }

  /// Un tocco su un campo dei dettagli: anche senza cambiarlo, il campo è una
  /// scelta dell'utente.
  void _onFieldTouched(ClothingField field) =>
      setState(() => _touched.add(field));

  CategoryPillState _pillState(ItemCategory category, ItemCategory? inferred) {
    if (_chosenCategory == category) return CategoryPillState.forced;
    if (inferred == category) return CategoryPillState.inferred;
    return CategoryPillState.inactive;
  }

  Future<void> _pickSpace(List<SpaceModel> spaces) async {
    final options = <_SpaceOption>[
      (id: null, name: 'spaces.default'.tr(), icon: Icons.inventory_2),
      for (final space in spaces)
        (
          id: space.id,
          name: space.name,
          icon: space.iconName != null
              ? SpaceIcons.getIcon(space.iconName!)
              : Icons.meeting_room,
        ),
    ];
    final picked = await DsPickerSheet.show<_SpaceOption>(
      context: context,
      title: 'items.select_space'.tr(),
      items: options,
      getLabel: (o) => o.name,
      getIcon: (o) => o.icon,
      selected: options.firstWhere(
        (o) => o.id == _spaceId,
        orElse: () => options.first,
      ),
      footerBuilder: (pickerContext) => DsLinkButton(
        key: const Key('picker_create_space'),
        label: 'spaces.add_new'.tr(),
        icon: Icons.add,
        onPressed: () async {
          final created = await showAddEditSpaceSheet(
            context,
            houseId: widget.houseId,
          );
          if (created != null && pickerContext.mounted) {
            Navigator.pop(pickerContext, (
              id: created.id,
              name: created.name,
              icon: SpaceIcons.getIcon(created.iconName ?? 'meeting_room'),
            ));
          }
        },
      ),
    );
    if (picked != null && mounted) setState(() => _spaceId = picked.id);
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_isScan) return _saveScan(widget.scanResult!);
    if (_isNew) return _create();
    final item = _item();
    if (item == null) {
      AppSnackBar.showError(context, 'errors.save_item_failed'.tr());
      Navigator.pop(context);
      return;
    }
    final note = _noteController.text.trim();
    final name = _nameController.text.trim();
    var metadata = _metadataFor(item.aiMetadata);
    // Una categoria toccata, anche se uguale, è una scelta dell'utente: l'AI
    // non la cambia più.
    if (_categoryTouched) metadata = withUserCategory(metadata);
    // Rinominato dopo che la scheda dell'AI era per il nome vecchio (mancava
    // all'apertura, o è arrivata a scheda aperta): i valori restano, ma la
    // scheda va chiesta di nuovo col nome nuovo.
    if (name != item.name &&
        (needsAiMetadata(_openedMetadata) ||
            item.aiMetadata != _openedMetadata)) {
      metadata = withAiPending(metadata);
    }
    final updated = item.copyWith(
      name: name,
      description: note.isEmpty ? null : note,
      category: _chosenCategory ?? item.category,
      quantity: _quantity,
      spaceId: _spaceId,
      aiMetadata: metadata,
      updatedAt: DateTime.now(),
    );
    final changedDetails = _changedDetailFields();
    setState(() => _isSaving = true);
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .updateItem(updated),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_item_failed'.tr(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!ok) return;
    if (changedDetails.isNotEmpty) {
      ref
          .read(coreAnalyticsServiceProvider)
          .trackItemDetailsEdited(source: 'house', fields: changedDetails);
    }
    Navigator.pop(context);
  }

  /// Dalla scansione non si scrive nulla: il capo modificato torna a chi ha
  /// aperto la scheda. I dettagli restano quelli dell'analisi se non sono
  /// cambiati, come nella modifica.
  void _saveScan(ClothingAnalysisResult result) {
    var edited = result;
    final details = _details;
    if (details != null && details != _originalDetails) {
      edited = details.applyTo(edited);
    }
    // Un dubbio su un campo che la categoria scelta non mostra non si può
    // controllare: non resta.
    final remainingDoubts = visibleDoubts([
      for (final field in result.doubts)
        if (_doubts.contains(field)) field,
    ], _fieldsFor(details, _currentCategory(null)));
    Navigator.pop(
      context,
      edited.copyWith(
        name: _nameController.text.trim(),
        appCategory: appCategoryKey(_chosenCategory ?? _scanCategory!),
        doubts: remainingDoubts,
      ),
    );
  }

  /// I metadati da salvare, a partire da [current], quelli dell'oggetto letti
  /// al salvataggio. Senza campi toccati restano come sono, byte per byte. Con
  /// campi toccati diventano scelte dell'utente: vedi [withUserDetails].
  String? _metadataFor(String? current) {
    final details = _details;
    if (_touched.isEmpty || details == null) return current;
    return withUserDetails(
      current: current,
      details: details,
      touched: _touched,
    );
  }

  /// Campi dei dettagli cambiati rispetto a quando la scheda si è aperta.
  List<String> _changedDetailFields() {
    final before = _originalDetails;
    final after = _details;
    if (before == null || after == null) return const [];
    return after.changedFields(before);
  }

  /// Crea l'oggetto con la categoria scelta, altrimenti quella dedotta dal
  /// nome, altrimenti "Varie": la stessa regola della pagina "Aggiungi".
  Future<void> _create() async {
    final note = _noteController.text.trim();
    final now = DateTime.now();
    final item = ItemModel(
      id: const Uuid().v4(),
      houseId: widget.houseId,
      name: _nameController.text.trim(),
      category:
          _chosenCategory ??
          _inferredCategory(
            ref.read(categoryInferServiceProvider).valueOrNull,
          ) ??
          ItemCategory.varie,
      description: note.isEmpty ? null : note,
      quantity: _quantity,
      spaceId: _spaceId,
      aiMetadata: _chosenCategory != null
          ? withUserCategory(_metadataFor(null))
          : _metadataFor(null),
      createdAt: now,
      updatedAt: now,
    );
    setState(() => _isSaving = true);
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .addItem(item, categoryChosen: _chosenCategory != null),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.create_item_failed'.tr(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.pop(context, item);
  }

  Future<void> _delete() async {
    final typed = _nameController.text.trim();
    final name = typed.isEmpty ? 'items.this_item'.tr() : typed;
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.item_type'.tr(),
      itemName: name,
    );
    if (confirmed != true || !mounted) return;
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .deleteItem(widget.itemId!, widget.houseId),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.delete_item_failed'.tr(args: [name]),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _moveToHouse() async {
    final dest = await BulkMoveSheet.show(
      context,
      itemCount: 1,
      sourceHouseId: widget.houseId,
    );
    if (dest == null || !mounted) return;
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .bulkMove([widget.itemId!], dest.houseId, spaceId: dest.spaceId),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.save_error'.tr(),
    );
    if (!ok || !mounted) return;
    AppSnackBar.showSuccess(
      context,
      'items.bulk_move_success'.tr(args: ['1', dest.houseDisplayName]),
    );
    Navigator.pop(context);
  }

  Widget _unavailable(Widget child) =>
      DsFormSheet(title: 'items.edit_item'.tr(), child: child);

  @override
  Widget build(BuildContext context) {
    // Solo la modifica legge l'oggetto dalla casa: il nuovo e quello della
    // scansione non ci sono ancora.
    if (!_isNew && !_isScan && !_isSaving) {
      final items = ref.watch(itemNotifierProvider(widget.houseId));
      final fallback = items.when<Widget?>(
        loading: () =>
            _unavailable(const Center(child: CircularProgressIndicator())),
        error: (error, _) => _unavailable(
          DsErrorState(
            error: error,
            title: 'errors.load_items'.tr(),
            onRetry: () => ref.invalidate(itemNotifierProvider(widget.houseId)),
          ),
        ),
        data: (items) {
          final item = items.where((i) => i.id == widget.itemId).firstOrNull;
          if (item == null) {
            return _unavailable(
              DsNotFoundState(
                title: 'items.not_found'.tr(),
                icon: Icons.inventory_2_outlined,
                actionLabel: 'common.close'.tr(),
                onAction: () => Navigator.pop(context),
              ),
            );
          }
          _hydrate(item);
          _refreshFrom(item);
          return null;
        },
      );
      if (fallback != null) return fallback;
    }
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spaces = _isScan
        ? const <SpaceModel>[]
        : ref.watch(spaceNotifierProvider(widget.houseId)).valueOrNull ??
              const <SpaceModel>[];
    final spaceName =
        spaces.where((s) => s.id == _spaceId).firstOrNull?.name ??
        'spaces.default'.tr();
    final inferred = _isScan
        ? null
        : _inferredCategory(
            ref.watch(categoryInferServiceProvider).valueOrNull,
          );
    final footnote = widget.footnote;
    final category = _currentCategory(inferred);
    // Nel nuovo oggetto e nella scansione `itemId` è null: la riga c'è solo in
    // modifica.
    final enriching = ref.watch(itemEnrichmentProvider).contains(widget.itemId);

    // Durante il salvataggio il foglio non si chiude: chi l'ha aperto aspetta
    // l'oggetto creato.
    return DsFormSheet(
      title: _isNew ? 'items.new_item'.tr() : 'items.edit_item'.tr(),
      actions: [
        if (!_isNew && !_isScan)
          PopupMenuButton<_ItemMenu>(
            key: const Key('item_sheet_menu'),
            icon: const Icon(Icons.more_vert),
            onSelected: (choice) => switch (choice) {
              _ItemMenu.move => _moveToHouse(),
              _ItemMenu.delete => _delete(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _ItemMenu.move,
                child: Text('items.move_to_house'.tr()),
              ),
              PopupMenuItem(
                value: _ItemMenu.delete,
                child: Text(
                  'common.delete'.tr(),
                  style: textTheme.bodyLarge?.copyWith(color: cs.error),
                ),
              ),
            ],
          ),
      ],
      actionLabel: widget.submitLabel ?? 'common.save'.tr(),
      actionIcon: widget.submitIcon,
      actionKey: const Key('item_sheet_save'),
      // In modifica, a riposo il foglio non ha arancio pieno: "Salva" si
      // accende alla prima modifica.
      onSubmit: _isNew || _isDirty ? _save : null,
      isBusy: _isSaving,
      // La prima etichetta ha già il suo spazio sopra: niente padding in cima.
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.spacingMd,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsFieldLabel.prominent('items.name_label'.tr()),
            DsTextField(
              key: const Key('item_sheet_name'),
              controller: _nameController,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              // Ridisegna la proposta di categoria.
              onChanged: (_) => setState(() {}),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'common.name_required_validation'.tr()
                  : null,
            ),
            DsFieldLabel.prominent('items.category_label'.tr()),
            SizedBox(
              key: const Key('item_sheet_category'),
              height: context.responsive(AppConstants.categoryRowHeight),
              child: Row(
                children: [
                  for (final category in ItemCategory.values) ...[
                    if (category != ItemCategory.values.first)
                      SizedBox(width: context.spacingXs),
                    Expanded(
                      child: CategoryPill(
                        category: category,
                        pillState: _pillState(category, inferred),
                        onTap: () => _tapCategory(category),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isScan) ...[
              _InlineField(
                label: 'items.quantity'.tr(),
                child: QuantityStepper(
                  value: _quantity,
                  minValue: 1,
                  // Neutro: nella scheda l'arancio è del bottone
                  // e della categoria scelta.
                  accentColor: cs.onSurface,
                  onChanged: (v) => setState(() => _quantity = v),
                ),
              ),
              _InlineField(
                label: 'items.space_label'.tr(),
                child: InkWell(
                  key: const Key('item_sheet_space'),
                  borderRadius: BorderRadius.circular(
                    AppConstants.inputBorderRadius,
                  ),
                  onTap: () => _pickSpace(spaces),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacingSm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            spaceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: context.iconSizeMd,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_details case final details?
                when _fieldsFor(details, category).isNotEmpty) ...[
              // I dettagli hanno titoli dello stesso stile del
              // resto della scheda: una linea li separa, senza un
              // titolo "Dettagli" che li sovrasti.
              Padding(
                padding: EdgeInsets.only(top: context.spacingLg),
                child: const DsDivider(),
              ),
              if (enriching) const _PendingDetailsRow(),
              ClothingDetailsSection(
                details: details,
                fields: _fieldsFor(details, category),
                onChanged: (d) => setState(() => _details = d),
                onFieldTouched: _onFieldTouched,
                doubts: _doubts,
                onDoubtResolved: (field) =>
                    setState(() => _doubts.remove(field)),
              ),
            ],
            if (!_isScan) ...[
              DsFieldLabel.prominent('items.note_label'.tr()),
              DsTextField(
                key: const Key('item_sheet_note'),
                controller: _noteController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                hintText: 'items.add_note'.tr(),
                // Ridisegna "Salva", attivo solo con una modifica.
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (footnote != null)
              Padding(
                padding: EdgeInsets.only(top: context.spacingMd),
                child: Text(
                  footnote,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La riga sopra i dettagli mentre la scheda dell'AI arriva. L'oggetto resta
/// modificabile.
class _PendingDetailsRow extends StatelessWidget {
  const _PendingDetailsRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: context.spacingSm),
      child: Row(
        children: [
          SizedBox.square(
            dimension: context.iconSizeSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
          SizedBox(width: context.spacingSm),
          Flexible(
            child: Text(
              'items.details_pending'.tr(),
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// I dettagli scritti in [aiMetadata]. Senza metadati, o non leggibili, sono
/// vuoti ("da scegliere"). Null per un oggetto che l'AI ha riconosciuto come
/// non capo: non ha dettagli.
ClothingDetails? _detailsOf(String? aiMetadata) {
  final map = _decodeMetadata(aiMetadata);
  if (map == null) return ClothingDetails.empty;
  if (map['category'] == 'Not Clothing') return null;
  return ClothingDetails.fromMetadata(map);
}

/// La mappa di [raw] (`items.ai_metadata`); null se manca o non si legge.
Map<String, dynamic>? _decodeMetadata(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

/// Etichetta come [DsFieldLabel] con il controllo sulla stessa riga, a
/// destra: per i valori brevi (quantità, spazio) che non chiedono un campo.
class _InlineField extends StatelessWidget {
  final String label;
  final Widget child;

  const _InlineField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacingSm),
      // Su una riga finché ci stanno entrambi: l'etichetta a sinistra, il
      // controllo a destra. Se non ci stanno, il controllo va a capo sotto,
      // allineato a destra, alla sua dimensione piena.
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: context.spacingMd,
        overflowSpacing: context.spacingXs,
        children: [
          Text(label, style: DsFieldLabel.prominentStyle(context)),
          child,
        ],
      ),
    );
  }
}
