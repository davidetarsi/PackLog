import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Etichetta di un gruppo di righe: "Vestiti · 7".
///
/// Per impostazione predefinita è un riferimento piccolo e grigio. La variante
/// [prominent] evidenzia invece il nome del gruppo e lascia conteggio e dettaglio
/// al livello secondario. Ha lo sfondo della pagina perché nelle liste sta in
/// un `PinnedHeaderSliver` e resta fissa mentre scorrono le righe del gruppo.
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

  /// Mostra il nome del gruppo come titolo e i metadati come testo secondario.
  final bool prominent;

  const DsGroupHeader({
    super.key,
    required this.label,
    this.count,
    this.detail,
    this.expanded,
    this.onTap,
    this.prominent = false,
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
    final labelStyle = prominent
        ? theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          )
        : theme.textTheme.labelLarge?.copyWith(color: color);
    final detailStyle = theme.textTheme.labelLarge?.copyWith(color: color);
    final richText = prominent
        ? TextSpan(
            children: [
              TextSpan(text: label, style: labelStyle),
              if (count != null)
                TextSpan(text: ' · $count', style: detailStyle),
              if (detail != null)
                TextSpan(text: ' · $detail', style: detailStyle),
            ],
          )
        : null;

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
                  child: prominent
                      ? Text.rich(
                          richText!,
                          key: const Key('group_header_text'),
                        )
                      : Text(
                          text,
                          key: const Key('group_header_text'),
                          style: labelStyle,
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
