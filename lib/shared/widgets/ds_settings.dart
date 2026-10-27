import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/surface_colors.dart';

/// Blocco di righe di impostazioni: il componente standard dei moduli
/// (oggetto, casa, spazio, bagaglio, viaggio). Le righe sono separate da
/// linee rientrate, il blocco ha angoli arrotondati e uno sfondo appena
/// diverso dalla pagina.
class DsSettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const DsSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: context.spacingMd,
                endIndent: context.spacingMd,
                color: cs.outlineVariant,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// Riga di un [DsSettingsGroup]: etichetta a sinistra; a destra un
/// controllo ([trailing]) oppure il valore corrente ([value]) con la freccia
/// se la riga apre una scelta. [subtitle] è una spiegazione breve sotto
/// l'etichetta, per le righe che da sole non si capiscono.
///
/// [destructive] colora etichetta e icona di errore (es. "Elimina"); [enabled]
/// `false` spegne la riga: niente tocco e colore disabilitato. L'icona di
/// [leading] va senza colore esplicito, altrimenti la riga non può tingerla.
class DsSettingsRow extends StatelessWidget {
  final String label;
  final Widget? leading;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool enabled;

  const DsSettingsRow({
    super.key,
    required this.label,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final value = this.value;
    final leading = this.leading;
    // Colore del testo e dell'icona: il disabilitato vince sul distruttivo.
    final Color? tint = !enabled
        ? cs.onSurface.withValues(alpha: 0.38)
        : destructive
        ? cs.error
        : null;
    final end =
        trailing ??
        (value == null
            ? null
            // Il valore non supera metà riga: l'etichetta resta leggibile
            // anche con nomi lunghi scritti dall'utente.
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      SizedBox(width: context.spacingXs),
                      Icon(
                        Icons.chevron_right,
                        size: context.iconSizeSm,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ));

    final subtitle = this.subtitle;
    return ListTile(
      enabled: enabled,
      // IconTheme interno: il colore della riga vince su quello disabilitato
      // che ListTile applica alle sue icone.
      leading: leading == null || tint == null
          ? leading
          : IconTheme.merge(
              data: IconThemeData(color: tint),
              child: leading,
            ),
      minTileHeight: context.responsive(56),
      contentPadding: EdgeInsets.symmetric(horizontal: context.spacingMd),
      title: Text(label, style: textTheme.bodyLarge?.copyWith(color: tint)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
      trailing: end,
      onTap: onTap,
    );
  }
}
