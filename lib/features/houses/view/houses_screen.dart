import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../providers/house_stats_provider.dart';
import '../model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/design_system/design_system.dart';

class HousesScreen extends ConsumerWidget {
  const HousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Case')),
      body: housesAsync.when(
        data: (houses) {
          if (houses.isEmpty) {
            return const EmptyState(
              icon: Icons.home_outlined,
              title: 'Nessuna casa',
              subtitle: 'Aggiungi la tua prima casa',
            );
          }

          // Ordina le case: prima quella principale, poi le altre
          final sortedHouses = houses.toList()
            ..sort((a, b) {
              if (a.isPrimary && !b.isPrimary) return -1;
              if (!a.isPrimary && b.isPrimary) return 1;
              return 0;
            });

          return ListView.builder(
            padding: const EdgeInsets.only(
              bottom: AppConstants.floatingNavBarPadding,
            ),
            itemCount: sortedHouses.length,
            itemBuilder: (context, index) {
              final house = sortedHouses[index];
              return _HouseCard(house: house);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          error: error,
          onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _HouseCard extends ConsumerWidget {
  final HouseModel house;

  const _HouseCard({required this.house});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(houseStatsProvider(house.id));

    return Card(
      margin: context.responsiveSymmetricPadding(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius + 4,
        ),
        side: BorderSide(
          color:
              colorScheme.outline.withValues(alpha: 0.2),
          width: /* house.isPrimary ? 1.5 : */ 1,
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: context.responsiveBorderRadius(
              AppConstants.cardBorderRadius + 4,
            ),
            onTap: () {
              context.push('/houses/${house.id}');
            },
            child: Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.spacingSm + 4),
                        decoration: BoxDecoration(
                          color: house.isPrimary
                              ? colorScheme.primary.withValues(alpha: 0.1)
                              : colorScheme.primaryContainer,
                          borderRadius: context.responsiveBorderRadius(
                            AppConstants.cardBorderRadius,
                          ),
                        ),
                        child: Icon(
                          HouseIcons.getIcon(house.iconName),
                          color: house.isPrimary
                              ? colorScheme.primary
                              : colorScheme.onPrimaryContainer,
                          size: context.iconSizeMd,
                        ),
                      ),
                      SizedBox(width: context.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              house.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: context.fontSizeLg,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (house.locationDisplayName != null || house.description != null) ...[
                              SizedBox(height: context.spacingXs),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      house.locationDisplayName ?? house.description!,
                                      style: TextStyle(
                                        fontSize: context.fontSizeSm + 1,
                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Divider
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacingMd),
                    child: Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  
                  // Stats row
                  statsAsync.when(
                    data: (stats) => Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${stats.totalItems} oggetti salvati',
                          style: TextStyle(
                            fontSize: context.fontSizeSm,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        if (stats.hasItemsInTrip)
                          _Badge(
                            label: 'In viaggio',
                            color: colorScheme.primary,
                          ),
                        if (stats.hasItemsInTrip && stats.hasTemporaryItems)
                          const SizedBox(width: 8),
                        if (stats.hasTemporaryItems)
                          _Badge(
                            label: 'Ospite',
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    loading: () => const SizedBox(height: 20),
                    error: (error, stackTrace) => const SizedBox(height: 20),
                  ),
                ],
              ),
            ),
          ),
          
          // Badge principale in alto a destra (stile bookmark/salvato)
          if (house.isPrimary)
            Positioned(
              top: 0,
              right: 12,
              child: Icon(
                Icons.bookmark,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget per i badge "In viaggio" e "Ospite"
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
