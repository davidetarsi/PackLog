// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/items/model/item_model.dart';
import '../../features/trips/model/trip_model.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/ds_badge.dart';
import '../widgets/trip_cards.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stub data
// ─────────────────────────────────────────────────────────────────────────────

final _stubTrip = TripModel(
  id: 'showcase-1',
  name: 'Vacanza a Milano',
  departureDateTime: DateTime.now().add(const Duration(days: 3)),
  returnDateTime: DateTime.now().add(const Duration(days: 10)),
  destinationLocation: null,
  items: [
    TripItem(
      id: 'i1',
      name: 'Passaporto',
      category: ItemCategory.varie,
      quantity: 1,
      isChecked: true,
    ),
    TripItem(
      id: 'i2',
      name: 'Caricabatterie',
      category: ItemCategory.elettronica,
      quantity: 2,
      isChecked: true,
    ),
    TripItem(
      id: 'i3',
      name: 'Maglione',
      category: ItemCategory.vestiti,
      quantity: 3,
      isChecked: false,
    ),
    TripItem(
      id: 'i4',
      name: 'Scarpe',
      category: ItemCategory.vestiti,
      quantity: 1,
      isChecked: false,
    ),
    TripItem(
      id: 'i5',
      name: 'Shampoo',
      category: ItemCategory.toiletries,
      quantity: 1,
      isChecked: false,
    ),
  ],
  isSaved: false,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final _stubTripCompleted = TripModel(
  id: 'showcase-2',
  name: 'Weekend Roma',
  departureDateTime: DateTime.now().subtract(const Duration(days: 10)),
  returnDateTime: DateTime.now().subtract(const Duration(days: 7)),
  items: [
    TripItem(
      id: 'c1',
      name: 'Passaporto',
      category: ItemCategory.varie,
      quantity: 1,
      isChecked: true,
    ),
    TripItem(
      id: 'c2',
      name: 'Maglione',
      category: ItemCategory.vestiti,
      quantity: 2,
      isChecked: true,
    ),
  ],
  isSaved: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// ─────────────────────────────────────────────────────────────────────────────
// DsThemeShowcaseScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Schermata di debug per l'ispezione visiva del Design System.
///
/// Accessibile solo in `kDebugMode` tramite il route `/dev/ds-showcase`.
/// Mostra tutte le componenti chiave del DS in modalità Light e Dark
/// affiancate per verificare contrasto WCAG AA e coerenza cromatica.
///
/// Sezioni:
///  1. Palette semantica (colori + opacità)
///  2. Scala tipografica
///  3. Badges (DsQuantityBadge, DsStatusBadge, DsInfoBadge)
///  4. Card viaggi (TripCardHero, TripCardCompact)
///  5. Card case (HouseCard mock)
class DsThemeShowcaseScreen extends StatelessWidget {
  const DsThemeShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DS Theme Showcase'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Chip(
              label: const Text('DEV ONLY'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: AppSpacing.fontXxs,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: const [
          _SectionDivider(label: '1 · Palette Semantica'),
          _ColorPaletteSection(),
          _SectionDivider(label: '2 · Scala Tipografica'),
          _TypographySection(),
          _SectionDivider(label: '3 · Badge System'),
          _BadgesSection(),
          _SectionDivider(label: '4 · Trip Cards'),
          _TripCardsSection(),
          _SectionDivider(label: '5 · House Card Mock'),
          _HouseCardSection(),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Intestazione di sezione con etichetta.
class _SectionDivider extends StatelessWidget {
  final String label;

  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppSpacing.fontXxs,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

/// Colonna Light|Dark con intestazione
class _DualThemeColumn extends StatelessWidget {
  final Widget Function(BuildContext ctx, ThemeData theme) builder;

  const _DualThemeColumn({required this.builder});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    '☀️  LIGHT',
                    style: TextStyle(
                      fontSize: AppSpacing.fontXxs,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '🌙  DARK',
                    style: TextStyle(
                      fontSize: AppSpacing.fontXxs,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Content row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Theme(
                data: AppTheme.light,
                child: Builder(builder: (ctx) => builder(ctx, AppTheme.light)),
              ),
            ),
            Expanded(
              child: Theme(
                data: AppTheme.dark,
                child: Builder(builder: (ctx) => builder(ctx, AppTheme.dark)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1 · Color Palette
// ─────────────────────────────────────────────────────────────────────────────

class _ColorPaletteSection extends StatelessWidget {
  const _ColorPaletteSection();

  @override
  Widget build(BuildContext context) {
    return _DualThemeColumn(
      builder: (ctx, theme) {
        final cs = theme.colorScheme;
        final appColors = theme.extension<AppColorsExtension>();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: [
              _ColorRow(
                label: 'primary',
                color: cs.primary,
                onColor: cs.onPrimary,
              ),
              _ColorRow(
                label: 'primaryContainer',
                color: cs.primaryContainer,
                onColor: cs.onPrimaryContainer,
              ),
              _ColorRow(
                label: 'secondary',
                color: cs.secondary,
                onColor: cs.onSecondary,
              ),
              _ColorRow(
                label: 'tertiary (on-trip)',
                color: cs.tertiary,
                onColor: cs.onTertiary,
              ),
              _ColorRow(
                label: 'tertiaryContainer',
                color: cs.tertiaryContainer,
                onColor: cs.onTertiaryContainer,
              ),
              _ColorRow(label: 'error', color: cs.error, onColor: cs.onError),
              _ColorRow(
                label: 'surface',
                color: cs.surface,
                onColor: cs.onSurface,
              ),
              _ColorRow(
                label: 'surfaceContainer',
                color: cs.surfaceContainer,
                onColor: cs.onSurface,
              ),
              _ColorRow(
                label: 'onSurfaceVariant',
                color: cs.onSurfaceVariant,
                onColor: cs.surface,
              ),
              _ColorRow(
                label: 'outline',
                color: cs.outline,
                onColor: cs.surface,
              ),
              _ColorRow(
                label: 'outlineVariant',
                color: cs.outlineVariant,
                onColor: cs.onSurface,
              ),
              if (appColors != null) ...[
                _ColorRow(
                  label: 'success (ext)',
                  color: appColors.success,
                  onColor: appColors.onSuccess,
                ),
                _ColorRow(
                  label: 'successContainer',
                  color: appColors.successContainer,
                  onColor: appColors.onSuccessContainer,
                ),
                _ColorRow(
                  label: 'warning (ext)',
                  color: appColors.warning,
                  onColor: cs.onPrimary,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final Color onColor;

  const _ColorRow({
    required this.label,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppSpacing.fontXxs,
          color: onColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · Typography Scale
// ─────────────────────────────────────────────────────────────────────────────

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  static const _scale = [
    ('Xxs / 12 · w600 · badge', AppSpacing.fontXxs, FontWeight.w600),
    ('Xs / 14 · w500 · caption', AppSpacing.fontXs, FontWeight.w500),
    ('Sm / 16 · w500 · body', AppSpacing.fontSm, FontWeight.w500),
    ('Md / 18 · w700 · subtitle', AppSpacing.fontMd, FontWeight.w700),
    ('Lg / 20 · w700 · title', AppSpacing.fontLg, FontWeight.w700),
    ('Xl / 22 · w700 · heading', AppSpacing.fontXl, FontWeight.w700),
    ('Title / 24 · w600', AppSpacing.fontTitle, FontWeight.w600),
    ('Heading / 28 · w600', AppSpacing.fontHeading, FontWeight.w600),
    ('Display / 32 · w600', AppSpacing.fontDisplay, FontWeight.w600),
  ];

  @override
  Widget build(BuildContext context) {
    return _DualThemeColumn(
      builder: (ctx, theme) {
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, size, weight) in _scale)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: size,
                      fontWeight: weight,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'onSurfaceVariant · secondary text',
                style: TextStyle(
                  fontSize: AppSpacing.fontSm,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                'disabled · alpha 0.38',
                style: TextStyle(
                  fontSize: AppSpacing.fontSm,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 · Badges
// ─────────────────────────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  const _BadgesSection();

  @override
  Widget build(BuildContext context) {
    return _DualThemeColumn(
      builder: (ctx, theme) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              DsQuantityBadge(current: 3),
              DsQuantityBadge(current: 3, max: 5),
              DsQuantityBadge(current: 3, isSelected: true),
              DsStatusBadge(
                type: DsStatusBadgeType.onTrip,
                label: 'In viaggio',
              ),
              DsStatusBadge(type: DsStatusBadgeType.temporary, label: 'Ospite'),
              DsStatusBadge(
                type: DsStatusBadgeType.primary,
                label: 'Principale',
              ),
              DsStatusBadge(type: DsStatusBadgeType.success, label: 'Pronto'),
              DsInfoBadge(
                icon: Icons.calendar_today_outlined,
                label: '12–19 giu',
              ),
              DsInfoBadge(icon: Icons.location_on_outlined, label: 'Milano'),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4 · Trip Cards
// ─────────────────────────────────────────────────────────────────────────────

class _TripCardsSection extends StatelessWidget {
  const _TripCardsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'TripCardHero',
            style: TextStyle(
              fontSize: AppSpacing.fontXxs,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _DualThemeColumn(
          builder: (ctx, theme) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: ProviderScope(child: TripCardHero(trip: _stubTrip)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'TripCardCompact',
            style: TextStyle(
              fontSize: AppSpacing.fontXxs,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _DualThemeColumn(
          builder: (ctx, theme) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: ProviderScope(
                child: TripCardCompact(trip: _stubTripCompleted),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 · House Card Mock
// ─────────────────────────────────────────────────────────────────────────────

class _HouseCardSection extends StatelessWidget {
  const _HouseCardSection();

  @override
  Widget build(BuildContext context) {
    return _DualThemeColumn(
      builder: (ctx, theme) {
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: _HouseCardMock(
            name: 'Casa Milano',
            location: 'Milano, MI',
            iconName: 'home',
            isPrimary: true,
            itemCount: 42,
            colorScheme: cs,
          ),
        );
      },
    );
  }
}

/// Replica fedele del layout della HouseCard (senza dipendenze Riverpod).
class _HouseCardMock extends StatelessWidget {
  final String name;
  final String location;
  final String iconName;
  final bool isPrimary;
  final int itemCount;
  final ColorScheme colorScheme;

  const _HouseCardMock({
    required this.name,
    required this.location,
    required this.iconName,
    required this.isPrimary,
    required this.itemCount,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius + 4,
        ),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: context.cardPaddingDense,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: context.responsiveBorderRadius(
                      AppConstants.cardBorderRadius,
                    ),
                  ),
                  child: Icon(
                    Icons.home,
                    color: isPrimary ? cs.primary : cs.onPrimaryContainer,
                    size: context.iconSizeMd,
                  ),
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: context.fontSizeLg,
                          color: cs.onSurface,
                        ),
                      ),
                      SizedBox(height: context.spacingXs),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: TextStyle(
                              fontSize: context.fontSizeXs,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPrimary)
                  Icon(Icons.push_pin, size: 18, color: cs.primary),
              ],
            ),
            SizedBox(height: context.spacingMd),
            Row(
              children: [
                Text(
                  '$itemCount oggetti',
                  style: TextStyle(
                    fontSize: context.fontSizeXs,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                DsStatusBadge(
                  type: DsStatusBadgeType.primary,
                  label: 'Principale',
                  icon: Icons.push_pin,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
