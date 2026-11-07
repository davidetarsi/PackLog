import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_section_header.dart';

/// Una sezione del foglio "Perché queste scelte": intestazione con icona nel
/// colore [color] (titolo compreso) e, sotto, gli elementi in [children].
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
        ...children,
        SizedBox(height: context.spacingSm),
      ],
    );
  }
}
