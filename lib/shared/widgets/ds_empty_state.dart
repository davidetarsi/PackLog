import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/error_empty_theme_extension.dart';
import 'ds_button.dart';
import 'ds_link_button.dart';

/// Template degli stati vuoti: icona, titolo, sottotitolo opzionale e, sotto,
/// i contenuti che la schermata sceglie.
///
/// I contenuti standard sono due, entrambi strutturati:
/// - CTA ([ctaLabel], [ctaIcon], [onCta]): un [DsButton], l'azione principale.
/// - link ([linkLabel], [onLink]): un [DsLinkButton] sotto la CTA, la strada
///   secondaria.
///
/// [action] resta per i contenuti che non sono "bottone + link" (es. la riga
/// tratteggiata "Aggiungi la tua prima casa"). Non si usa insieme ai
/// parametri strutturati.
///
/// Esempio:
/// ```dart
/// DsEmptyState(
///   icon: Icons.inventory_2_outlined,
///   title: 'Nessun oggetto',
///   ctaLabel: 'Scansiona con AI',
///   ctaIcon: Icons.auto_awesome,
///   onCta: () {},
///   linkLabel: 'Scrivili a mano',
///   onLink: () {},
/// )
/// ```
class DsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Contenuto libero, solo quando non è "bottone + link". Non insieme ai
  /// parametri strutturati (CTA e link).
  final Widget? action;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double? iconSize;

  /// Solo per stati autonomi. Gli empty state dentro SliverFillRemaining
  /// devono conservare dimensioni intrinseche e lo scroll del contenitore.
  final bool scrollable;

  /// Callback opzionale invocata al tap sull'intero widget.
  final VoidCallback? onTap;

  /// Testo del hint mostrato sotto il subtitle quando [onTap] è fornito.
  final String? tapHint;

  /// CTA: etichetta del [DsButton]. Mostrata solo con [onCta].
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final DsButtonVariant ctaVariant;
  final Key? ctaKey;

  /// Link: etichetta del [DsLinkButton] sotto la CTA. Mostrato solo con
  /// [onLink].
  final String? linkLabel;
  final VoidCallback? onLink;
  final Key? linkKey;

  const DsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
    this.titleStyle,
    this.subtitleStyle,
    this.iconSize,
    this.scrollable = false,
    this.onTap,
    this.tapHint,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.ctaVariant = DsButtonVariant.primary,
    this.ctaKey,
    this.linkLabel,
    this.onLink,
    this.linkKey,
  }) : assert(
         action == null || (ctaLabel == null && linkLabel == null),
         'action è per contenuti liberi: non insieme a CTA e link',
       );

  @override
  Widget build(BuildContext context) {
    final theme = context.errorEmptyTheme;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: theme.stateSpacingLg),
          Icon(
            icon,
            size: iconSize ?? theme.emptyStateIconSize,
            color: iconColor ?? theme.emptyStateIconColor,
          ),
          SizedBox(height: theme.stateSpacingMd),
          Text(
            title,
            style: titleStyle ?? theme.emptyStateTitle,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null && tapHint == null) ...[
            SizedBox(height: theme.stateSpacingSm),
            Text(
              subtitle!,
              style: subtitleStyle ?? theme.emptyStateSubtitle,
              textAlign: TextAlign.center,
            ),
          ],
          if (tapHint != null) ...[
            SizedBox(height: theme.stateSpacingSm),
            Text(
              tapHint!,
              style: theme.emptyStateSubtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            SizedBox(height: theme.stateSpacingLg),
            action!,
          ],
          if (ctaLabel != null && onCta != null) ...[
            SizedBox(height: theme.stateSpacingLg),
            DsButton(
              key: ctaKey,
              label: ctaLabel!,
              icon: ctaIcon,
              variant: ctaVariant,
              onPressed: onCta,
            ),
          ],
          if (linkLabel != null && onLink != null) ...[
            SizedBox(height: context.spacingSm),
            DsLinkButton(key: linkKey, label: linkLabel!, onPressed: onLink!),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    if (!scrollable) return content;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Alias legacy. I nuovi call site usano [DsEmptyState].
@Deprecated('Use DsEmptyState')
typedef EmptyState = DsEmptyState;
