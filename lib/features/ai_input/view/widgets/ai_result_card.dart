import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/universal_item_tile.dart';
import '../../model/clothing_analysis_result.dart';

class AiResultCard extends StatelessWidget {
  final ClothingAnalysisResult item;
  final int index;
  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;
  final bool autofocus;

  const AiResultCard({
    super.key,
    required this.item,
    required this.index,
    required this.controller,
    required this.onNameChanged,
    required this.onDelete,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return UniversalItemTile(
      backgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      useListTile: false,
      contentPadding: EdgeInsets.symmetric(vertical: context.spacingXs),
      // Grigio e non arancione: l'icona dice da dove viene la riga, non è
      // un'azione. L'unico arancione della schermata resta la CTA.
      leading: Icon(
        Icons.auto_awesome_outlined,
        size: context.iconSizeSm,
        color: colorScheme.onSurfaceVariant,
      ),
      title: TextField(
        controller: controller,
        onChanged: onNameChanged,
        autofocus: autofocus,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        // Nessun riquadro attorno al nome: la pill lo faceva sembrare un
        // bottone, e la riga ha già il suo bordo inferiore (vedi
        // [UniversalItemTile], ramo `_isFlatRow`) a separarla dalla
        // successiva. Il campo si segnala solo quando lo si sta scrivendo.
        decoration: InputDecoration(
          hintText: 'ai_import.item_name_hint'.tr(),
          contentPadding: EdgeInsets.symmetric(vertical: context.spacingSm),
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
      ),
      trailing: IconButton(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
        color: colorScheme.error,
        tooltip: 'common.delete'.tr(),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: context.iconSizeMd,
          minHeight: context.iconSizeMd,
        ),
      ),
    );
  }
}
