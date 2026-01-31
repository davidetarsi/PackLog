import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';

class TripDetailScreen extends ConsumerWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return tripsAsync.when(
      data: (trips) {
        final matchingTrips = trips.where((t) => t.id == tripId);
        if (matchingTrips.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lista non trovata')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    size: context.iconSizeHero,
                    color: AppColors.disabled,
                  ),
                  SizedBox(height: context.spacingMd),
                  Text(
                    'Lista non trovata',
                    style: TextStyle(fontSize: context.fontSizeXl),
                  ),
                  SizedBox(height: context.spacingXl),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/trips'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Torna alle liste'),
                  ),
                ],
              ),
            ),
          );
        }

        final trip = matchingTrips.first;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(trip.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.push('/trips/$tripId/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Elimina lista'),
                      content: Text(
                        'Sei sicuro di voler eliminare "${trip.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => context.pop(false),
                          child: const Text('Annulla'),
                        ),
                        TextButton(
                          onPressed: () => context.pop(true),
                          child: const Text(
                            'Elimina',
                            style: TextStyle(color: AppColors.destructive),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(tripNotifierProvider.notifier)
                        .deleteTrip(tripId);
                    if (context.mounted) {
                      context.go('/trips');
                    }
                  }
                },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con progress
              Container(
                width: double.infinity,
                padding: context.responsiveScreenPadding,
                color: colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.description != null) ...[
                      Text(
                        trip.description!,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: context.spacingSm + 4),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: trip.completionPercentage,
                            backgroundColor: colorScheme.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              trip.completionPercentage == 1.0
                                  ? AppColors.success
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: context.spacingSm + 4),
                        Text(
                          '${trip.completedCount}/${trip.totalCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Lista items
              Expanded(
                child: trip.items.isEmpty
                    ? Center(
                        child: Text(
                          'Nessun oggetto nella lista',
                          style: TextStyle(
                            color: AppColors.disabled,
                            fontSize: context.fontSizeMd,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(context.spacingSm),
                        itemCount: trip.items.length,
                        itemBuilder: (context, index) {
                          final item = trip.items[index];
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: context.responsiveBorderRadius(
                                AppConstants.cardBorderRadius,
                              ),
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: item.isChecked,
                                onChanged: (_) {
                                  ref
                                      .read(tripNotifierProvider.notifier)
                                      .toggleItemCheck(tripId, item.id);
                                },
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  decoration: item.isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.isChecked
                                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: context.fontSizeSm,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              trailing: Text(
                                'x${item.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: context.iconSizeHero,
                color: AppColors.destructive,
              ),
              SizedBox(height: context.spacingMd),
              Text('Errore: $error'),
              SizedBox(height: context.spacingMd),
              ElevatedButton(
                onPressed: () {
                  ref.read(tripNotifierProvider.notifier).refresh();
                },
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
