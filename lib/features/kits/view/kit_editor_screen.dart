import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/search_match.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/cta_reserved_space.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_field_label.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../../../shared/widgets/ds_text_button.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/widgets/rapid_fire_input.dart';
import '../helpers/kit_draft_save.dart';
import '../helpers/kit_uses_choice.dart';
import '../model/kit_model.dart';
import '../providers/kit_provider.dart';
import '../repositories/kit_repository.dart';
import 'widgets/kit_house_matches.dart';
import 'widgets/kit_item_row.dart';
import 'widgets/kit_uses_picker.dart';

/// Nuovo kit e modifica: il nome, le pillole d'uso, "Nel kit" e il Rapid Fire
/// per aggiungere oggetti. Tutto resta in bozza fino a "Salva"; la schermata
/// si chiude con `true` se il kit è stato salvato.
class KitEditorScreen extends ConsumerStatefulWidget {
  const KitEditorScreen({
    super.key,
    required this.houseId,
    this.kitId,
    this.initialItemIds = const [],
    this.focusAdd = false,
  });

  final String houseId;

  /// Il kit da modificare; senza, ne nasce uno nuovo.
  final String? kitId;

  /// Oggetti già dentro il kit nuovo (dalla selezione della casa).
  final List<String> initialItemIds;

  /// Il Rapid Fire parte con la tastiera su.
  final bool focusAdd;

  @override
  ConsumerState<KitEditorScreen> createState() => _KitEditorScreenState();
}

class _KitEditorScreenState extends ConsumerState<KitEditorScreen> {
  final _name = TextEditingController();
  KitUsesChoice _uses = const KitUsesChoice();

  /// Id oggetto → copie, nell'ordine in cui sono entrati.
  late final Map<String, int> _items = {
    for (final id in widget.initialItemIds) id: 1,
  };
  String _query = '';
  KitModel? _existing;
  bool _hydrated = false;
  bool _busy = false;

  bool get _isNew => widget.kitId == null;
  bool get _canSave => _name.text.trim().isNotEmpty && !_busy;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate(KitModel kit) {
    if (_hydrated) return;
    _hydrated = true;
    _existing = kit;
    _name.text = kit.name;
    _uses = KitUsesChoice.of(kit);
    _items
      ..clear()
      ..addEntries(kit.items.map((i) => MapEntry(i.itemId, i.copies)));
  }

  void _onNameChanged(String name) => setState(() {
    if (_isNew) _uses = _uses.withName(name);
  });

  void _addItem(String itemId, int copies) {
    if (!_items.containsKey(itemId) && _items.length >= kMaxItemsPerKit) {
      AppSnackBar.showError(
        context,
        'kits.limit_items'.tr(args: ['$kMaxItemsPerKit']),
      );
      return;
    }
    setState(() => _items[itemId] = copies);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _busy = true);
    final notifier = ref.read(kitNotifierProvider(widget.houseId).notifier);
    try {
      await saveKitDraft(
        notifier,
        existing: _existing,
        name: _name.text,
        activities: _uses.activities,
        transports: _uses.transports,
        items: _items,
        onCreated: (kit) => _existing = kit,
      );
      if (mounted) context.pop(true);
    } on KitLimitException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.showError(
        context,
        (e.limit == kMaxKitsPerHouse ? 'kits.limit_kits' : 'kits.limit_items')
            .tr(args: ['${e.limit}']),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew) {
      final kits = ref.watch(kitNotifierProvider(widget.houseId)).valueOrNull;
      if (kits == null) return _scaffold(const SizedBox.shrink());
      final kit = kits.where((k) => k.id == widget.kitId).firstOrNull;
      if (kit == null && !_hydrated) {
        return _scaffold(
          DsNotFoundState(
            icon: Icons.inventory_2_outlined,
            title: 'kits.not_found'.tr(),
            actionLabel: 'common.close'.tr(),
            onAction: () => context.pop(),
          ),
        );
      }
      if (kit != null) _hydrate(kit);
    }
    return _scaffold(_form());
  }

  Widget _scaffold(Widget body) => StickyCtaScaffold(
    appBar: AppBar(
      title: Text((_isNew ? 'kits.new_title' : 'kits.edit_title').tr()),
      actions: [
        DsTextButton(
          key: const Key('kit_save'),
          label: 'common.save'.tr(),
          accent: true,
          onPressed: _canSave ? _save : null,
        ),
      ],
    ),
    body: body,
    bottomContent: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: RapidFireInput(
        houseId: widget.houseId,
        autofocus: widget.focusAdd,
        onTextChanged: (q) => setState(() => _query = q),
        onItemCreated: (item) => _addItem(item.id, item.quantity ?? 1),
      ),
    ),
  );

  Widget _form() {
    final houseItems =
        ref.watch(itemNotifierProvider(widget.houseId)).valueOrNull ??
        const <ItemModel>[];
    final byId = {for (final item in houseItems) item.id: item};
    final inKit = [
      for (final e in _items.entries)
        if (byId.containsKey(e.key)) (byId[e.key]!, e.value),
    ];
    final matches = _query.trim().length < 2
        ? const <ItemModel>[]
        : [
            for (final item in houseItems)
              if (!_items.containsKey(item.id) &&
                  matchesSearch(item.name, _query))
                item,
          ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.spacingMd + context.ctaReservedHeight,
      ),
      // Toccare i contenuti legati al campo non lo chiude.
      child: TapRegion(
        groupId: rapidFireTapRegionGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsFieldLabel('kits.name_label'.tr()),
            DsTextField(
              key: const Key('kit_name_field'),
              controller: _name,
              autofocus: _isNew && !widget.focusAdd,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              hintText: 'kits.name_hint'.tr(),
              maxLength: kMaxKitNameLength,
              onChanged: _onNameChanged,
            ),
            KitUsesPicker(
              choice: _uses,
              onToggle: (id) => setState(() => _uses = _uses.toggle(id)),
            ),
            DsFieldLabel.prominent('kits.in_kit'.tr(args: ['${inKit.length}'])),
            if (inKit.isNotEmpty)
              DsSettingsGroup(
                children: [
                  for (final (item, copies) in inKit)
                    KitItemRow(
                      key: Key('kit_item_row_${item.id}'),
                      name: item.name,
                      copies: copies,
                      onCopiesChanged: (n) =>
                          setState(() => _items[item.id] = n),
                      removeKey: Key('kit_item_remove_${item.id}'),
                      onRemove: () => setState(() => _items.remove(item.id)),
                    ),
                ],
              ),
            KitHouseMatches(
              matches: matches,
              onPick: (item) => _addItem(item.id, 1),
            ),
          ],
        ),
      ),
    );
  }
}
