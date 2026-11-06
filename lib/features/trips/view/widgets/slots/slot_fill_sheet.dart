import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/helpers/search_match.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_button.dart';
import '../../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../../shared/widgets/ds_search_field.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../../items/helpers/copies_parser.dart';
import '../../../../items/model/item_model.dart';
import '../../../../items/providers/item_provider.dart';
import '../../../../items/widgets/rapid_fire_input.dart';
import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';
import '../../../providers/trip_provider.dart';
import 'slot_copies_label.dart';
import 'slot_written_row.dart';

/// Apre il foglio per riempire [slot] con i propri oggetti.
Future<void> showSlotFillSheet(
  BuildContext context, {
  required AiSlot slot,
  required String houseId,
  required String tripId,
  required Future<void> Function(TripItem item) onFill,
  required VoidCallback onToBuy,
}) => showDsSheet<void>(
  context,
  builder: (_) => SlotFillSheet(
    slot: slot,
    houseId: houseId,
    tripId: tripId,
    onFill: onFill,
    onToBuy: onToBuy,
  ),
);

class SlotFillSheet extends ConsumerStatefulWidget {
  const SlotFillSheet({
    super.key,
    required this.slot,
    required this.houseId,
    required this.tripId,
    required this.onFill,
    required this.onToBuy,
  });

  final AiSlot slot;
  final String houseId;
  final String tripId;
  final Future<void> Function(TripItem item) onFill;
  final VoidCallback onToBuy;

  @override
  ConsumerState<SlotFillSheet> createState() => _SlotFillSheetState();
}

class _SlotFillSheetState extends ConsumerState<SlotFillSheet> {
  final _written = <TripItem>[];
  final _searchController = TextEditingController();
  final _fillingIds = <String>{};
  late int _remaining = widget.slot.remaining;
  Future<void> _fillQueue = Future<void>.value();
  int _pendingFills = 0;
  String _rapidText = '';
  bool _searchOpen = false;

  bool get _done => _remaining == 0 && _pendingFills == 0;
  bool get _saving => _pendingFills > 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ItemModel> _availableItems(List<ItemModel> items, TripModel? trip) {
    return items.where((item) => _available(item, trip) > 0).toList();
  }

  int _available(ItemModel item, TripModel? trip) {
    final alreadyPacked = trip?.items
        .where((packed) => packed.id == item.id)
        .fold<int>(0, (total, packed) => total + packed.quantity);
    final writtenHere = _written
        .where((packed) => packed.id == item.id)
        .fold<int>(0, (total, packed) => total + packed.quantity);
    return (item.quantity ?? 1) -
        ((alreadyPacked ?? 0) > writtenHere
            ? (alreadyPacked ?? 0)
            : writtenHere);
  }

  Future<void> _onSaved(ItemModel item) async {
    await _fill(
      TripItem(
        id: item.id,
        name: item.name,
        category: item.category,
        quantity: item.quantity ?? 1,
        originHouseId: item.houseId,
      ),
    );
  }

  Future<void> _fill(TripItem item) {
    if (mounted) setState(() => _pendingFills++);
    final operation = _fillQueue.then((_) => _performFill(item));
    _fillQueue = operation.catchError((Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _performFill(TripItem item) async {
    if (!mounted) {
      try {
        await widget.onFill(item);
      } catch (_) {
        // Una chiusura durante il salvataggio non annulla la scrittura.
      }
      return;
    }
    try {
      await widget.onFill(item);
    } catch (_) {
      // Il chiamante avvisa già dell'errore; non si scala il residuo.
      return;
    } finally {
      if (mounted) setState(() => _pendingFills--);
    }
    if (!mounted) return;
    setState(() {
      final index = _written.indexWhere((written) => written.id == item.id);
      if (index == -1) {
        _written.add(item);
      } else {
        _written[index] = _written[index].copyWith(
          quantity: _written[index].quantity + item.quantity,
        );
      }
      _remaining = (_remaining - item.quantity).clamp(0, _remaining);
    });
  }

  void _openSearch() {
    final text = _rapidText.trim();
    _searchController.text = (parseCopies(text)?.name ?? text).trim();
    setState(() => _searchOpen = true);
  }

  void _onRapidTextChanged(String value) {
    _rapidText = value;
    setState(() {});
  }

  void _toBuy() {
    Navigator.of(context).pop();
    widget.onToBuy();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final copies = slotCopiesLabel(
      slot.copyWith(remaining: _remaining),
      always: true,
    )!;
    final inventory = ref.watch(itemNotifierProvider(widget.houseId));
    final trip = ref
        .watch(tripNotifierProvider)
        .valueOrNull
        ?.where((candidate) => candidate.id == widget.tripId)
        .firstOrNull;
    final availableItems = _availableItems(
      inventory.valueOrNull ?? const <ItemModel>[],
      trip,
    );
    final allItems = inventory.valueOrNull ?? const <ItemModel>[];
    final query = _searchController.text.trim();
    final matches = query.length < 2
        ? const <ItemModel>[]
        : availableItems
              .where((item) => matchesSearch(item.name, query))
              .toList();
    final duplicateName = allItems.any(
      (item) =>
          normalizeForSearch(item.name) ==
          normalizeForSearch(parseCopies(_rapidText)?.name ?? _rapidText),
    );

    return DsFormSheet(
      title: '${slot.name} $copies',
      actions: [
        if (!_done && !slot.toBuy)
          DsTextButton(
            key: const Key('slot_sheet_to_buy'),
            label: 'trips.slots.to_buy'.tr(),
            onPressed: _saving ? null : _toBuy,
          ),
      ],
      footer: _done
          ? Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: DsButton(
                key: const Key('slot_sheet_done'),
                label: 'trips.slots.close'.tr(),
                onPressed: () => Navigator.of(context).pop(),
                expand: true,
              ),
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacingMd,
                context.spacingXs,
                context.spacingMd,
                context.spacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'trips.slots.new_item_hint'.tr(),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  SizedBox(height: context.spacingSm),
                  RapidFireInput(
                    key: ValueKey('slot_sheet_input_${slot.id}'),
                    houseId: widget.houseId,
                    autofocus: true,
                    hintText: 'trips.slots.rapid_fire_hint'.tr(),
                    enabled: !_saving,
                    onTextChanged: _onRapidTextChanged,
                    onItemSaved: _onSaved,
                  ),
                ],
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _done
                ? 'trips.slots.completed'.tr()
                : 'trips.slots.open_hint'.tr(args: ['${slot.copies}']),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (!_done && duplicateName)
            Padding(
              padding: EdgeInsets.only(top: context.spacingSm),
              child: Text(
                'trips.slots.duplicate_name'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (_written.isNotEmpty) ...[
            SizedBox(height: context.spacingMd),
            Text('trips.slots.added_title'.tr(), style: tt.titleSmall),
            for (final item in _written)
              SlotWrittenRow(key: ValueKey(item.id), item: item),
          ],
          if (!_done && !_searchOpen)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('slot_open_inventory_search'),
                onPressed: _openSearch,
                child: Text('trips.slots.search_inventory'.tr()),
              ),
            ),
          if (!_done && _searchOpen) ...[
            SizedBox(height: context.spacingMd),
            DsSearchField(
              key: const Key('slot_inventory_search'),
              controller: _searchController,
              autofocus: true,
              hintText: 'trips.slots.search_inventory'.tr(),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: context.spacingXs),
            Text(
              'trips.slots.search_suitability'.tr(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (matches.isNotEmpty) ...[
              SizedBox(height: context.spacingMd),
              Text('trips.slots.items_found'.tr(), style: tt.titleSmall),
              for (final item in matches)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.spacingXs),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.name, style: tt.bodyLarge)),
                      Text(
                        '×${_available(item, trip)}',
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: context.spacingSm),
                      TextButton(
                        onPressed: _saving || _fillingIds.contains(item.id)
                            ? null
                            : () async {
                                final freshItems = ref
                                    .read(itemNotifierProvider(widget.houseId))
                                    .valueOrNull;
                                final freshItem = freshItems
                                    ?.where(
                                      (candidate) => candidate.id == item.id,
                                    )
                                    .firstOrNull;
                                final freshTrip = ref
                                    .read(tripNotifierProvider)
                                    .valueOrNull
                                    ?.where(
                                      (candidate) =>
                                          candidate.id == widget.tripId,
                                    )
                                    .firstOrNull;
                                if (freshItem == null) return;
                                final quantity = math.min(
                                  _available(freshItem, freshTrip),
                                  _remaining,
                                );
                                if (quantity <= 0) return;
                                setState(() => _fillingIds.add(item.id));
                                try {
                                  await _fill(
                                    TripItem(
                                      id: freshItem.id,
                                      name: freshItem.name,
                                      category: freshItem.category,
                                      quantity: quantity,
                                      originHouseId: freshItem.houseId,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _fillingIds.remove(item.id));
                                  }
                                }
                              },
                        child: Text('trips.slots.add'.tr()),
                      ),
                    ],
                  ),
                ),
            ] else if (query.length >= 2)
              Padding(
                padding: EdgeInsets.only(top: context.spacingMd),
                child: Text(
                  'trips.slots.no_inventory_match'.tr(),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
