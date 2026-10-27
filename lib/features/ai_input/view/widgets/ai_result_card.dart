import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_opacity.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ds_checkbox.dart';
import '../../../../shared/widgets/ds_dashed_box.dart';
import '../../../../shared/widgets/ds_text_button.dart';
import '../../../items/model/clothing_details.dart';
import '../../../items/model/clothing_labels.dart';
import '../../helpers/ai_item_category.dart';
import '../../model/clothing_analysis_result.dart';

/// Valore non utile da mostrare: vuoto o 'N/A'.
bool _isMissing(String value) =>
    value.trim().isEmpty || value.trim().toUpperCase() == 'N/A';

/// Riga dei dettagli del capo: tipo e colore di base, tradotti e nell'ordine
/// della scheda. I valori vuoti o 'N/A' non compaiono.
String aiDetailsLine(ClothingAnalysisResult result) => [
  if (!_isMissing(result.subCategory)) clothingTypeLabel(result.subCategory),
  colorLabel(result.baseColor),
].where((value) => value.isNotEmpty).join(' · ');

/// Riga di un capo riconosciuto: inclusione, poi nome, tipo e colore ed
/// eventuali dati da controllare. Toccando la riga si apre la scheda del capo,
/// dove si cambia anche il nome. "C'è già?" a destra.
class AiResultCard extends StatelessWidget {
  final ClothingAnalysisResult item;

  /// Il nome mostrato: lo aggiorna chi apre la scheda, dopo un salvataggio.
  final TextEditingController controller;
  final bool included;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback? onAlreadyHere;
  final VoidCallback? onOpenDetails;
  final bool enabled;

  const AiResultCard({
    super.key,
    required this.item,
    required this.controller,
    required this.included,
    required this.onIncludedChanged,
    required this.onOpenDetails,
    this.onAlreadyHere,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: AppOpacity.disabled);
    // Tre livelli: il nome in evidenza, tipo e colore in grigio, il dato da
    // controllare in una pillola tratteggiata. Nessun testo sotto 14.
    final nameStyle = textTheme.cardTitle?.copyWith(
      color: included ? colors.onSurface : muted,
    );
    final detailStyle = textTheme.bodyMedium?.copyWith(
      color: included ? colors.onSurfaceVariant : muted,
    );
    // Solo i dubbi che la scheda mostra per la categoria del capo: gli altri
    // non si potrebbero controllare.
    final doubts = visibleDoubts(
      item.doubts,
      clothingFieldsFor(
        aiItemCategory(item.category, appCategory: item.appCategory),
        item.subCategory,
      ),
    );
    final details = aiDetailsLine(item);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsCheckbox(
            value: included,
            onChanged: !enabled ? null : (value) => onIncludedChanged(value),
          ),
          Expanded(
            child: InkWell(
              key: const Key('ai_result_details'),
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
              onTap: enabled ? onOpenDetails : null,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacingXs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) =>
                                Text(value.text, style: nameStyle),
                          ),
                          if (details.isNotEmpty) ...[
                            SizedBox(height: context.spacingXxs),
                            Text(
                              details,
                              style: detailStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (doubts.isNotEmpty) ...[
                            SizedBox(height: context.spacingXs),
                            _ToCheck(
                              count: doubts.length,
                              color: included ? colors.onSurface : muted,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: context.iconSizeMd,
                      color: included ? colors.onSurfaceVariant : muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onAlreadyHere != null)
            DsTextButton(
              key: const Key('ai_already_here'),
              onPressed: enabled ? onAlreadyHere : null,
              label: 'ai_import.already_here'.tr(),
            ),
        ],
      ),
    );
  }
}

/// "N da controllare" in una pillola tratteggiata, come i valori da
/// controllare nella scheda del capo.
class _ToCheck extends StatelessWidget {
  const _ToCheck({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DsDashedBox(
      key: const Key('ai_result_to_check'),
      radius: AppConstants.pillBorderRadius,
      color: color,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingXxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: context.iconSizeSm, color: color),
            SizedBox(width: context.spacingXs),
            // Su uno schermo stretto, con "C'è già?" accanto, va a capo.
            Flexible(
              child: Text(
                'ai_import.to_check'.plural(count),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
