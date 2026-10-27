import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Effetto vetro della barra (sfocatura dello sfondo). Se sul telefono la
/// sfocatura fa scattare lo scorrimento, metti `false`: la barra torna a una
/// superficie tonale piena.
const bool _kGlassBar = true;

/// Barra flottante a voci uguali: la barra di navigazione e quella della
/// selezione multipla. Ogni figlio prende la stessa larghezza.
class DsFloatingBar extends StatelessWidget {
  final List<Widget> children;

  const DsFloatingBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = context.responsiveBorderRadius(
      AppConstants.pillBorderRadius,
    );

    Widget bar = Container(
      height: context.responsive(56.0),
      decoration: BoxDecoration(
        color: _kGlassBar
            ? colorScheme.surfaceContainer.withValues(alpha: 0.78)
            : colorScheme.surfaceContainer,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final child in children) Expanded(child: child)],
      ),
    );
    if (_kGlassBar) {
      bar = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: bar,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: bar,
    );
  }
}

/// Voce di una [DsFloatingBar].
///
/// Neutra anche da selezionata: la voce attiva si riconosce dall'icona
/// piena e dalla lineetta arancio sul bordo superiore. [accent] la colora di
/// arancio (Crea nella navigazione). Senza [onTap] è spenta.
class DsBarItem extends StatelessWidget {
  /// Key dell'area toccabile, per il tour guidato.
  final Key? anchorKey;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool accent;

  const DsBarItem({
    super.key,
    this.anchorKey,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : accent
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Semantics(
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: InkWell(
        key: anchorKey,
        onTap: onTap,
        borderRadius: context.responsiveBorderRadius(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? (selectedIcon ?? icon) : icon,
                  size: context.responsive(22),
                  color: color,
                ),
                SizedBox(height: context.spacingXxs),
                // L'altezza della barra è fissa: con caratteri molto grandi
                // la scritta non deve spingere l'icona fuori.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                child: Container(
                  key: const Key('nav_indicator'),
                  width: context.spacingLg,
                  height: context.spacingXs,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(AppConstants.smallBorderRadius),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
