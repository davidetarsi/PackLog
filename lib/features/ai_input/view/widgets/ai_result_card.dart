import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
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
      leading: Icon(
        Icons.auto_awesome_outlined,
        size: context.iconSizeSm,
        color: colorScheme.primary,
      ),
      title: TextField(
        controller: controller,
        onChanged: onNameChanged,
        autofocus: autofocus,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'ai_import.item_name_hint'.tr(),
          contentPadding: EdgeInsets.symmetric(
            vertical: context.spacingMd,
            horizontal: context.spacingMd,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
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
