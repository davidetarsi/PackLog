import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';

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
                  const Icon(Icons.luggage_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Lista non trovata',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 32),
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
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(tripNotifierProvider.notifier).deleteTrip(tripId);
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
                padding: const EdgeInsets.all(16),
                color: colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.description != null) ...[
                      Text(
                        trip.description!,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: trip.completionPercentage,
                            backgroundColor: colorScheme.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              trip.completionPercentage == 1.0
                                  ? Colors.green
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                    ? const Center(
                        child: Text(
                          'Nessun oggetto nella lista',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: trip.items.length,
                        itemBuilder: (context, index) {
                          final item = trip.items[index];
                          return Card(
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
                                      ? colorScheme.onSurface.withOpacity(0.5)
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                '${item.category} • Quantità: ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              trailing: Icon(
                                item.isChecked
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: item.isChecked ? Colors.green : Colors.grey,
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
      ),
    );
  }
}

