import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_divider.dart';
import '../../../../../shared/widgets/ds_section_header.dart';

/// Una sezione del foglio "Perché queste scelte": intestazione con icona nel
/// colore [color] (titolo compreso) e, sotto, gli elementi in [children]
/// dentro un riquadro come le card della valigia, separati da divisori.
class AiReasonSection extends StatelessWidget {
  const AiReasonSection({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader.withIcon(
          icon: icon,
          label: title,
          color: color,
          padding: EdgeInsets.only(bottom: context.spacingSm),
        ),
        Material(
          color: context.groupSurface,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) DsDivider(indent: context.spacingMd),
                child,
              ],
            ],
          ),
        ),
        SizedBox(height: context.spacingLg),
      ],
    );
  }
}
