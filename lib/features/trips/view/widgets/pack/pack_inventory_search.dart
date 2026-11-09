import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/helpers/design_system.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_search_field.dart';
import '../../../../houses/providers/house_provider.dart';
import '../../../../items/model/item_model.dart';
import '../../../../items/providers/item_provider.dart';
import '../../../../items/view/item_sheet.dart';
import '../ai/ai_wardrobe_row.dart';
import 'pack_parts.dart';

class PackInventorySearch extends ConsumerStatefulWidget {
  final String houseId;
  final Set<String> excludedItemIds;
  final TextEditingController? controller;
  final ValueChanged<String>? onQueryChanged;
  final Future<void> Function(ItemModel item, int copies) onAdd;

  const PackInventorySearch({
    super.key,
    required this.houseId,
    required this.excludedItemIds,
    this.controller,
    this.onQueryChanged,
    required this.onAdd,
  });

  @override
  ConsumerState<PackInventorySearch> createState() =>
      _PackInventorySearchState();
}

class _PackInventorySearchState extends ConsumerState<PackInventorySearch> {
  TextEditingController? _ownedController;
  String _query = '';

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _query = _controller.text.trim();
  }

  @override
  void didUpdateWidget(covariant PackInventorySearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controllerFor(oldWidget).removeListener(_handleControllerChanged);
      _controller.addListener(_handleControllerChanged);
      _query = _controller.text.trim();
    }
  }

  TextEditingController _controllerFor(PackInventorySearch widget) =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  void _handleControllerChanged() {
    final query = _controller.text.trim();
    if (_query == query) return;
    setState(() => _query = query);
    widget.onQueryChanged?.call(query);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(itemNotifierProvider(widget.houseId))
        .when(
          data: (items) => _buildResults(context, items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DsErrorState(
            error: error,
            title: 'errors.load_items'.tr(),
            onRetry: () => ref.invalidate(itemNotifierProvider(widget.houseId)),
          ),
        );
  }

  Widget _buildResults(BuildContext context, List<ItemModel> items) {
    final normalized = _query.toLowerCase();
    final results = normalized.isEmpty
        ? const <ItemModel>[]
        : items
              .where(
                (item) =>
                    !widget.excludedItemIds.contains(item.id) &&
                    item.name.toLowerCase().contains(normalized),
              )
              .toList();
    final exact =
        normalized.isNotEmpty &&
        items.any((item) => item.name.trim().toLowerCase() == normalized);
    final showAdd =
        normalized.isNotEmpty &&
        !exact &&
        (results.isEmpty || normalized.length >= 3);
    final houseName =
        ref
            .watch(houseNotifierProvider)
            .valueOrNull
            ?.where((house) => house.id == widget.houseId)
            .firstOrNull
            ?.displayName ??
        '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSearchField(
          controller: _controller,
          hintText: 'trips.pack.ai.search_hint'.tr(),
        ),
        if (_query.isNotEmpty) ...[
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
                      key: Key('pack_inventory_result_${item.id}'),
                      name: item.name,
                      subtitle: item.category.displayName,
                      onAdd: () => widget.onAdd(item, 1),
                    ),
                ],
              ),
            ),
          if (results.isNotEmpty && showAdd)
            SizedBox(height: context.spacingMd),
          if (showAdd)
            PackAddRow(
              key: const Key('pack_inventory_add_row'),
              name: _query,
              houseName: houseName,
              onTap: () async {
                final created = await showNewItemSheet(
                  context,
                  houseId: widget.houseId,
                  initialName: _query,
                  submitLabel: 'trips.pack.add_and_pack'.tr(),
                  submitIcon: Icons.luggage_outlined,
                  footnote: 'trips.pack.also_in_house'.tr(args: [houseName]),
                );
                if (created == null || !mounted) return;
                _controller.text = created.name;
                await widget.onAdd(created, created.quantity ?? 1);
              },
            ),
          if (results.isEmpty && !showAdd)
            Text(
              'items.no_search_results'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}
