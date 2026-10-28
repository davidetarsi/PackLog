import 'package:flutter/material.dart';

import 'ds_button.dart';
import 'ds_empty_state.dart';

/// Incapsula il pattern pull-to-refresh su stato vuoto.
///
/// Usa `CustomScrollView + SliverFillRemaining(hasScrollBody: false)` per
/// centrare il contenuto nel viewport abilitando il gesto pull-to-refresh,
/// con degradazione graceful a scrollabile se il contenuto supera l'altezza
/// disponibile (font grandi, landscape, testi lunghi).
///
/// I contenuti (CTA, link, [action]) sono quelli di [DsEmptyState].
///
/// ```dart
/// RefreshableEmptyState(
///   onRefresh: () => ref.refresh(provider.future),
///   icon: Icons.home_outlined,
///   title: 'houses.no_houses_title'.tr(),
/// )
/// ```
class RefreshableEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Contenuto libero, non insieme a CTA e link. Vedi [DsEmptyState.action].
  final Widget? action;
  final Color? iconColor;

  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final DsButtonVariant ctaVariant;
  final Key? ctaKey;

  final String? linkLabel;
  final VoidCallback? onLink;
  final Key? linkKey;

  const RefreshableEmptyState({
    super.key,
    required this.onRefresh,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.ctaVariant = DsButtonVariant.primary,
    this.ctaKey,
    this.linkLabel,
    this.onLink,
    this.linkKey,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: icon,
              title: title,
              subtitle: subtitle,
              action: action,
              iconColor: iconColor,
              ctaLabel: ctaLabel,
              ctaIcon: ctaIcon,
              onCta: onCta,
              ctaVariant: ctaVariant,
              ctaKey: ctaKey,
              linkLabel: linkLabel,
              onLink: onLink,
              linkKey: linkKey,
            ),
          ),
        ],
      ),
    );
  }
}
