import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/core_analytics_service.dart';
import '../../../../shared/helpers/search_match.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_error_state.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../../shared/widgets/ds_sheet_header.dart';
import '../../../../shared/widgets/ds_badge.dart';
import '../../../houses/providers/house_provider.dart';
import '../../../items/model/item_model.dart';
import '../../../items/providers/item_provider.dart';
import '../../helpers/ai_item_category.dart';
import '../../model/clothing_analysis_result.dart';
import 'ai_result_card.dart' show aiDetailsLine;

// Sotto 360 px quantità e azione richiedono una riga separata.
const _compactRowBreakpoint = 360.0;

/// Apre "C'è già?" e restituisce l'id dell'oggetto manuale a cui aggiungere
/// i dettagli AI, oppure `null` quando il foglio viene chiuso.
Future<String?> showAlreadyHereSheet(
  BuildContext context, {
  required String houseId,
  required ClothingAnalysisResult scanned,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _AlreadyHereSheet(houseId: houseId, scanned: scanned),
);

/// Numero di parole distinte del capo presenti nel nome dell'oggetto.
/// Serve solo per ordinare i candidati: non dichiara mai un doppione.
int alreadyHereScore(ClothingAnalysisResult scanned, ItemModel item) {
  final words = [scanned.subCategory, scanned.baseColor, scanned.name]
      .expand((text) => text.split(RegExp(r'[\s.,;:!?()]+')))
      .map(normalizeForSearch)
      .where((word) => word.length >= 3)
      .toSet();
  final itemName = normalizeForSearch(item.name);
  return words.where(itemName.contains).length;
}

class _AlreadyHereSheet extends ConsumerStatefulWidget {
  const _AlreadyHereSheet({required this.houseId, required this.scanned});

  final String houseId;
  final ClothingAnalysisResult scanned;

  @override
  ConsumerState<_AlreadyHereSheet> createState() => _AlreadyHereSheetState();
}

class _AlreadyHereSheetState extends ConsumerState<_AlreadyHereSheet> {
  bool _othersOpen = false;
  bool _openedTracked = false;
  bool _detailsTapped = false;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemNotifierProvider(widget.houseId));
    final houseName = ref
        .watch(houseNotifierProvider)
        .when(
          data: (houses) => houses
              .where((house) => house.id == widget.houseId)
              .firstOrNull
              ?.displayName,
          loading: () => null,
          error: (_, _) => null,
        );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sameCategory = aiItemCategory(
      widget.scanned.category,
      appCategory: widget.scanned.appCategory,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSheetHeader(
            title: houseName == null
                ? 'ai_import.already_here_default_title'.tr()
                : 'ai_import.already_here_title'.tr(args: [houseName]),
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: itemsAsync.when(
              loading: () => Padding(
                padding: EdgeInsets.all(context.spacingLg),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => DsErrorState(
                error: error,
                message: 'ai_import.already_here_load_error'.tr(),
                onRetry: () =>
                    ref.invalidate(itemNotifierProvider(widget.houseId)),
              ),
              data: (items) {
                final matchingCategory = items
                    .where((item) => item.category == sameCategory)
                    .toList();
                final ranked =
                    matchingCategory
                        .map(
                          (item) =>
                              (item, alreadyHereScore(widget.scanned, item)),
                        )
                        .toList()
                      ..sort((a, b) => b.$2.compareTo(a.$2));
                final similar = [
                  for (final entry in ranked)
                    if (entry.$2 > 0) entry.$1,
                ];
                final others = [
                  for (final entry in ranked)
                    if (entry.$2 == 0) entry.$1,
                ];

                if (!_openedTracked) {
                  _openedTracked = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ref
                        .read(coreAnalyticsServiceProvider)
                        .trackAlreadyHereOpened(
                          hasManualCandidates: similar.any(
                            (item) => item.aiMetadata == null,
                          ),
                        );
                  });
                }

                Widget itemRow(ItemModel item, {required bool canAddDetails}) {
                  final showAction = canAddDetails && item.aiMetadata == null;
                  final hasTrailing = (item.quantity ?? 1) > 1 || showAction;
                  Widget title({bool includeQuantity = false}) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.aiMetadata != null) ...[
                        SizedBox(width: context.spacingXs),
                        Icon(
                          Icons.auto_awesome,
                          size: context.iconSizeSm,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                      if (includeQuantity && (item.quantity ?? 1) > 1) ...[
                        SizedBox(width: context.spacingXs),
                        DsQuantityBadge(current: item.quantity!),
                      ],
                    ],
                  );
                  Widget actions({bool includeQuantity = true}) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (includeQuantity && (item.quantity ?? 1) > 1)
                        DsQuantityBadge(current: item.quantity!),
                      if (showAction) ...[
                        SizedBox(width: context.spacingXs),
                        TextButton(
                          key: ValueKey('add_details_${item.id}'),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingSm,
                            ),
                          ),
                          onPressed: _detailsTapped
                              ? null
                              : () {
                                  if (_detailsTapped || !mounted) return;
                                  _detailsTapped = true;
                                  ref
                                      .read(coreAnalyticsServiceProvider)
                                      .trackAlreadyHereDetailsAdded();
                                  Navigator.pop(context, item.id);
                                },
                          child: Text('ai_import.add_details'.tr()),
                        ),
                      ],
                    ],
                  );

                  return SizedBox(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < _compactRowBreakpoint) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: context.spacingXs,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                title(includeQuantity: true),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: actions(includeQuantity: false),
                                ),
                              ],
                            ),
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: title()),
                            if (hasTrailing) actions(),
                          ],
                        );
                      },
                    ),
                  );
                }

                final categoryLabel = sameCategory.displayName.toLowerCase();
                final photoDetails = [
                  widget.scanned.name,
                  aiDetailsLine(widget.scanned),
                ].where((part) => part.trim().isNotEmpty).join(' · ');

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.spacingMd,
                        context.spacingSm,
                        context.spacingMd,
                        0,
                      ),
                      child: Text(
                        'ai_import.from_photo'.tr(args: [photoDetails]),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacingMd,
                        ),
                        children: [
                          if (similar.isNotEmpty) ...[
                            DsGroupHeader(
                              label: 'ai_import.most_similar'.tr(),
                              count: similar.length,
                            ),
                            for (final item in similar)
                              itemRow(item, canAddDetails: true),
                          ],
                          if (others.isNotEmpty) ...[
                            DsGroupHeader(
                              label: sameCategory == ItemCategory.varie
                                  ? 'ai_import.others_items'.tr()
                                  : 'ai_import.others_of'.tr(
                                      args: [categoryLabel],
                                    ),
                              count: others.length,
                              expanded: _othersOpen,
                              onTap: () =>
                                  setState(() => _othersOpen = !_othersOpen),
                            ),
                            if (_othersOpen)
                              for (final item in others)
                                itemRow(item, canAddDetails: false),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.all(context.spacingMd),
                        child: Text(
                          'ai_import.already_here_help'.tr(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
