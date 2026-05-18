import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_spacing.dart';

class ContentSlide extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;

  const ContentSlide({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: colorScheme.primary),
          SizedBox(height: context.spacingLg),
          Text(
            titleKey.tr(),
            style: TextStyle(
              fontSize: context.fontSizeLg,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacingMd),
          Text(
            descriptionKey.tr(),
            style: TextStyle(
              fontSize: context.fontSizeSm,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
