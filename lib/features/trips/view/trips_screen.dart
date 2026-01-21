import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';
import '../model/trip_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  /// Stima l'altezza di una card in base al suo contenuto
  static double _estimateCardHeight(TripModel trip) {
    const maxPreviewItems = 5;
    double height = 60; // Base: titolo + padding

    if (trip.description != null) {
      height += 20; // Descrizione
    }

    if (trip.items.isNotEmpty) {
      height += 40; // Progress bar + counter + spacing
      final itemsToShow = trip.items.length > maxPreviewItems
          ? maxPreviewItems
          : trip.items.length;
      height += itemsToShow * 24; // Ogni item ~24px

      if (trip.items.length > maxPreviewItems) {
        height += 20; // "+N altri"
      }
    }

    return height;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripNotifierProvider);

    return tripsAsync.when(
      data: (trips) {
        if (trips.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.luggage_outlined,
                  size: 64,
                  color: AppColors.disabled,
                ),
                SizedBox(height: 16),
                Text(
                  'Nessuna lista di viaggio',
                  style: TextStyle(fontSize: 18, color: AppColors.disabled),
                ),
                SizedBox(height: 8),
                Text(
                  'Crea la tua prima lista',
                  style: TextStyle(fontSize: 14, color: AppColors.disabled),
                ),
              ],
            ),
          );
        }

        // Layout stile Google Keep masonry con due colonne
        // Assegna ogni trip alla colonna più corta per un vero effetto masonry
        final leftColumnTrips = <TripModel>[];
        final rightColumnTrips = <TripModel>[];
        double leftColumnHeight = 0;
        double rightColumnHeight = 0;

        for (final trip in trips) {
          final cardHeight = _estimateCardHeight(trip);
          if (leftColumnHeight <= rightColumnHeight) {
            leftColumnTrips.add(trip);
            leftColumnHeight += cardHeight + 8; // +8 per il padding
          } else {
            rightColumnTrips.add(trip);
            rightColumnHeight += cardHeight + 8;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: AppConstants.floatingNavBarPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonna sinistra
              Expanded(
                child: Column(
                  children: leftColumnTrips
                      .map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TripCard(trip: trip),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              // Colonna destra
              Expanded(
                child: Column(
                  children: rightColumnTrips
                      .map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TripCard(trip: trip),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.destructive,
            ),
            const SizedBox(height: 16),
            Text('Errore: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(tripNotifierProvider.notifier).refresh();
              },
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;

  const _TripCard({required this.trip});

  // Numero massimo di item da mostrare nella preview
  static const int _maxPreviewItems = 5;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calcola quanti item mostrare (max 5)
    final itemsToShow = trip.items.length > _maxPreviewItems
        ? _maxPreviewItems
        : trip.items.length;

    return Card(
      elevation: 2,
      margin: EdgeInsets
          .zero, // Rimuove il margine di default per controllare gli spazi
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        onTap: () {
          context.push('/trips/${trip.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Altezza dinamica
            children: [
              // Titolo
              Text(
                trip.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (trip.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  trip.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              // Progress bar
              if (trip.items.isNotEmpty) ...[
                LinearProgressIndicator(
                  value: trip.completionPercentage,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trip.completionPercentage == 1.0
                        ? AppColors.success
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.completedCount}/${trip.totalCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Lista items (preview) - ora con Column invece di ListView
              ...List.generate(itemsToShow, (index) {
                final item = trip.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        item.isChecked
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: item.isChecked
                            ? AppColors.success
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isChecked
                                ? colorScheme.onSurface.withOpacity(0.5)
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (trip.items.length > _maxPreviewItems)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${trip.items.length - _maxPreviewItems} altri',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
