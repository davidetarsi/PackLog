import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Etichetta di un gruppo di righe: "Vestiti · 7".
///
/// Piccola e grigia: è un riferimento, non un titolo né un'azione. Ha lo
/// sfondo della pagina perché nelle liste sta in un `PinnedHeaderSliver` e
/// resta fissa in alto mentre le righe del gruppo le scorrono sotto.
///
/// Con [expanded] non nullo il gruppo è chiudibile: compare la freccetta e
/// [onTap] apre o chiude.
class DsGroupHeader extends StatelessWidget {
  final String label;
  final int? count;

  /// Aggiunta in coda, es. la provenienza dei temporanei.
  final String? detail;

  /// `null` = gruppo non chiudibile.
  final bool? expanded;
  final VoidCallback? onTap;

  const DsGroupHeader({
    super.key,
    required this.label,
    this.count,
    this.detail,
    this.expanded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final text = [
      label,
      if (count != null) '$count',
      if (detail != null) detail!,
    ].join(' · ');

    return Semantics(
      button: onTap != null,
      expanded: expanded,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(
              top: context.spacingMd,
              bottom: context.spacingSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
                if (expanded != null)
                  Icon(
                    expanded! ? Icons.expand_less : Icons.expand_more,
                    size: context.iconSizeSm,
                    color: color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
