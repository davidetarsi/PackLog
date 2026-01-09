import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';

class HouseDetailScreen extends ConsumerWidget {
  final String houseId;

  const HouseDetailScreen({super.key, required this.houseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return housesAsync.when(
      data: (houses) {
        final matchingHouses = houses.where((h) => h.id == houseId);
        if (matchingHouses.isEmpty) {
          // Casa non trovata - mostra schermata di errore invece di reindirizzare
          return Scaffold(
            appBar: AppBar(title: const Text('Casa non trovata')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'La casa richiesta non è stata trovata.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home),
                    label: const Text('Torna alla lista case'),
                  ),
                ],
              ),
            ),
          );
        }
        final house = matchingHouses.first;
        return Scaffold(
          appBar: AppBar(
            title: Text(house.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.push('/houses/$houseId/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Elimina casa'),
                      content: Text(
                        'Sei sicuro di voler eliminare "${house.name}"?',
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
                    await ref
                        .read(houseNotifierProvider.notifier)
                        .deleteHouse(houseId);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: ItemsScreen(houseId: houseId, houseName: house.name),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              context.push('/houses/$houseId/items/new');
            },
            child: const Icon(Icons.add),
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Errore: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(houseNotifierProvider.notifier).refresh();
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
