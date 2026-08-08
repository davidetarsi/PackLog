import 'package:flutter/material.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';

/// Tile selezionabile per la scelta della lingua nella dialog di lingua.
///
/// Mostra bandiera, nome della lingua e un indicatore di selezione attiva.
class LanguageTile extends StatelessWidget {
  final Locale locale;
  final String title;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageTile({
    super.key,
    required this.locale,
    required this.title,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      child: Container(
        padding: EdgeInsets.all(context.spacingMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          color: isSelected ? colorScheme.primaryContainer : null,
        ),
        child: Row(
          children: [
            Text(flag, style: TextStyle(fontSize: context.fontSizeDisplay)),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected ? colorScheme.primary : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
