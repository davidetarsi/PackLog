import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_text_button.dart';
import '../../../items/model/clothing_labels.dart';
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

/// Riga di un capo riconosciuto: inclusione, nome modificabile sul posto,
/// dettagli (con accesso alla scheda) e "C'è già?".
class AiResultCard extends StatefulWidget {
  final ClothingAnalysisResult item;
  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;
  final bool included;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback? onAlreadyHere;
  final VoidCallback? onOpenDetails;
  final bool enabled;

  const AiResultCard({
    super.key,
    required this.item,
    required this.controller,
    required this.onNameChanged,
    required this.included,
    required this.onIncludedChanged,
    required this.onOpenDetails,
    this.onAlreadyHere,
    this.enabled = true,
  });

  @override
  State<AiResultCard> createState() => _AiResultCardState();
}

class _AiResultCardState extends State<AiResultCard> {
  bool _editing = false;

  void _stopEditing() {
    if (_editing) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active = widget.included;
    final muted = colors.onSurface.withValues(alpha: 0.38);
    final nameStyle = textTheme.titleMedium?.copyWith(
      color: active ? colors.onSurface : muted,
    );
    final detailStyle = textTheme.bodyMedium?.copyWith(
      color: active ? colors.onSurfaceVariant : muted,
    );
    final doubtStyle = textTheme.bodyMedium?.copyWith(
      color: active ? colors.onSurface : muted,
    );
    final doubts = widget.item.doubts;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: active,
            onChanged: !widget.enabled
                ? null
                : (value) => widget.onIncludedChanged(value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editing)
                  TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    autofocus: true,
                    style: nameStyle,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: widget.onNameChanged,
                    onSubmitted: (_) => _stopEditing(),
                    onTapOutside: (_) => _stopEditing(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'ai_import.item_name_hint'.tr(),
                    ),
                  )
                else
                  InkWell(
                    key: const Key('ai_result_name'),
                    onTap: widget.enabled
                        ? () => setState(() => _editing = true)
                        : null,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(widget.controller.text, style: nameStyle),
                        ),
                        SizedBox(width: context.spacingXs),
                        Icon(
                          Icons.edit_outlined,
                          size: context.iconSizeSm,
                          color: widget.enabled
                              ? colors.onSurfaceVariant
                              : muted,
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: context.spacingXs / 2),
                InkWell(
                  key: const Key('ai_result_details'),
                  onTap: widget.enabled ? widget.onOpenDetails : null,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          aiDetailsLine(widget.item),
                          style: detailStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: context.spacingXs),
                      Icon(
                        Icons.chevron_right,
                        size: context.iconSizeSm,
                        color: active ? colors.onSurfaceVariant : muted,
                      ),
                    ],
                  ),
                ),
                if (doubts.isNotEmpty) ...[
                  SizedBox(height: context.spacingXs / 2),
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: context.iconSizeSm,
                        color: active ? colors.onSurface : muted,
                      ),
                      SizedBox(width: context.spacingXs),
                      Flexible(
                        child: Text(
                          'ai_import.to_check'.plural(doubts.length),
                          style: doubtStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (widget.onAlreadyHere != null)
            DsTextButton(
              key: const Key('ai_already_here'),
              onPressed: widget.enabled ? widget.onAlreadyHere : null,
              label: 'ai_import.already_here'.tr(),
            ),
        ],
      ),
    );
  }
}
