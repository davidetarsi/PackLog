import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Blocco di righe di impostazioni: il componente standard dei moduli
/// (oggetto, casa, spazio, bagaglio, viaggio). Le righe sono separate da
/// linee rientrate, il blocco ha angoli arrotondati e uno sfondo appena
/// diverso dalla pagina.
class DsSettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const DsSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // In chiaro bianco sulla pagina crema; in scuro un grigio più chiaro
    // della pagina, come i gruppi di Revolut.
    final background = theme.brightness == Brightness.light
        ? cs.surfaceContainerLowest
        : cs.surfaceContainer;

    return Material(
      color: background,
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
/// se la riga apre una scelta.
class DsSettingsRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const DsSettingsRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final value = this.value;
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

    return ListTile(
      minTileHeight: context.responsive(56),
      contentPadding: EdgeInsets.symmetric(horizontal: context.spacingMd),
      title: Text(label, style: textTheme.bodyLarge),
      trailing: end,
      onTap: onTap,
    );
  }
}
