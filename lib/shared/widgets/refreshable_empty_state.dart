import 'package:flutter/material.dart';

import 'ds_empty_state.dart';

/// Incapsula il pattern pull-to-refresh su stato vuoto.
///
/// Usa `CustomScrollView + SliverFillRemaining(hasScrollBody: false)` per
/// centrare il contenuto nel viewport abilitando il gesto pull-to-refresh,
/// con degradazione graceful a scrollabile se il contenuto supera l'altezza
/// disponibile (font grandi, landscape, testi lunghi).
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
  final Widget? action;
  final Color? iconColor;

  const RefreshableEmptyState({
    super.key,
    required this.onRefresh,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
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
            ),
          ),
        ],
      ),
    );
  }
}
