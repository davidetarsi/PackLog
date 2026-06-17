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

  const AiResultCard({
    super.key,
    required this.item,
    required this.index,
    required this.controller,
    required this.onNameChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return UniversalItemTile(
      title: TextField(
        controller: controller,
        onChanged: onNameChanged,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration.collapsed(
          hintText: 'ai_import.item_name_hint'.tr(),
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
