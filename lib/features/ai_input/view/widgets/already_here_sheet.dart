import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/core_analytics_service.dart';
import '../../../../shared/helpers/search_match.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ds_badge.dart';
import '../../../../shared/widgets/ds_error_state.dart';
import '../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../houses/providers/house_provider.dart';
import '../../../items/model/item_metadata_merge.dart';
import '../../../items/model/item_model.dart';
import '../../../items/providers/item_provider.dart';
import '../../helpers/ai_item_category.dart';
import '../../model/clothing_analysis_result.dart';
import 'ai_result_card.dart' show aiDetailsLine;
import '../../../../shared/widgets/ds_glass_band.dart';

/// Apre "C'è già?": mostra gli oggetti della casa simili al capo scansionato.
/// È solo informativo: non collega né modifica nulla.
Future<void> showAlreadyHereSheet(
  BuildContext context, {
  required String houseId,
  required ClothingAnalysisResult scanned,
}) => showDsSheet<void>(
  context,
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

    return DsFormSheet(
      title: houseName == null
          ? 'ai_import.already_here_default_title'.tr()
          : 'ai_import.already_here_title'.tr(args: [houseName]),
      // Lo scroll sta nella cornice: qui il contenuto non ha padding proprio.
      padding: EdgeInsets.zero,
      footer: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spacingMd,
          DsGlassBand.topGap(context),
          context.spacingMd,
          context.spacingMd,
        ),
        child: Text(
          'ai_import.already_here_help'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
      child: itemsAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.all(context.spacingLg),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => DsErrorState(
          error: error,
          title: 'ai_import.already_here_load_error'.tr(),
          onRetry: () => ref.invalidate(itemNotifierProvider(widget.houseId)),
        ),
        data: (items) {
          final matchingCategory = items
              .where((item) => item.category == sameCategory)
              .toList();
          final ranked =
              matchingCategory
                  .map((item) => (item, alreadyHereScore(widget.scanned, item)))
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

          Widget itemRow(ItemModel item) => Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacingXs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.strong,
                  ),
                ),
                if (!needsAiMetadata(item.aiMetadata)) ...[
                  SizedBox(width: context.spacingXs),
                  Icon(
                    Icons.auto_awesome,
                    size: context.iconSizeSm,
                    color: cs.onSurfaceVariant,
                  ),
                ],
                if ((item.quantity ?? 1) > 1) ...[
                  SizedBox(width: context.spacingXs),
                  DsQuantityBadge(current: item.quantity!),
                ],
              ],
            ),
          );

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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Senza capi simili lo si dice, prima degli altri: così
                    // si capisce che il controllo c'è stato.
                    if (similar.isEmpty)
                      Padding(
                        key: const Key('already_here_nothing_similar'),
                        padding: EdgeInsets.only(top: context.spacingMd),
                        child: Text(
                          houseName == null
                              ? 'ai_import.nothing_similar_default'.tr()
                              : 'ai_import.nothing_similar'.tr(
                                  args: [houseName],
                                ),
                          style: theme.textTheme.bodyLarge?.strong,
                        ),
                      ),
                    if (similar.isNotEmpty) ...[
                      DsGroupHeader(
                        label: 'ai_import.most_similar'.tr(),
                        count: similar.length,
                      ),
                      for (final item in similar) itemRow(item),
                    ],
                    if (others.isNotEmpty) ...[
                      DsGroupHeader(
                        label: sameCategory == ItemCategory.varie
                            ? 'ai_import.others_items'.tr()
                            : 'ai_import.others_of'.tr(args: [categoryLabel]),
                        count: others.length,
                        expanded: _othersOpen,
                        onTap: () => setState(() => _othersOpen = !_othersOpen),
                      ),
                      if (_othersOpen)
                        for (final item in others) itemRow(item),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
