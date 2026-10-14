import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../model/clothing_analysis_result.dart';

/// Caratteristiche principali riconosciute dall'AI.
String aiDetailsLine(ClothingAnalysisResult result) => [
  result.subCategory,
  result.baseColor.toLowerCase(),
  result.pattern.toLowerCase(),
].where((value) => value.trim().isNotEmpty).join(' · ');

/// Riga di un capo riconosciuto con inclusione, modifica del nome e collegamento.
class AiResultCard extends StatefulWidget {
  final ClothingAnalysisResult item;
  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;
  final bool included;
  final ValueChanged<bool> onIncludedChanged;
  final bool isLinked;
  final String? linkedItemName;
  final VoidCallback? onAlreadyHere;
  final VoidCallback? onUnlink;
  final bool enabled;

  const AiResultCard({
    super.key,
    required this.item,
    required this.controller,
    required this.onNameChanged,
    required this.included,
    required this.onIncludedChanged,
    this.isLinked = false,
    this.linkedItemName,
    this.onAlreadyHere,
    this.onUnlink,
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
    final linked = widget.isLinked || widget.linkedItemName != null;
    final active = widget.included && !linked;
    final muted = colors.onSurface.withValues(alpha: 0.38);
    final nameStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: active ? colors.onSurface : muted,
    );
    final detailStyle = textTheme.bodySmall?.copyWith(
      color: active ? colors.onSurfaceVariant : muted,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXs),
      child: Row(
        children: [
          Checkbox(
            value: active,
            onChanged: !widget.enabled || linked
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
                Text(
                  linked
                      ? widget.linkedItemName == null
                            ? 'ai_import.linked_unknown'.tr()
                            : 'ai_import.linked'.tr(
                                args: [widget.linkedItemName!],
                              )
                      : aiDetailsLine(widget.item),
                  style: detailStyle,
                ),
              ],
            ),
          ),
          if (linked && widget.onUnlink != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: widget.enabled ? widget.onUnlink : null,
              child: Text('common.undo'.tr()),
            )
          else if (widget.onAlreadyHere != null)
            TextButton(
              key: const Key('ai_already_here'),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: widget.enabled ? widget.onAlreadyHere : null,
              child: Text('ai_import.already_here'.tr()),
            ),
        ],
      ),
    );
  }
}
