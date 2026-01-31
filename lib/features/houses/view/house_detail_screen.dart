import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../../items/view/items_screen.dart';
import '../../../shared/theme/theme.dart';
import 'add_edit_house_screen.dart';

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
                  Icon(
                    Icons.home_outlined,
                    size: context.iconSizeHero,
                    color: AppColors.disabled,
                  ),
                  SizedBox(height: context.spacingMd),
                  Text(
                    'La casa richiesta non è stata trovata.',
                    style: TextStyle(fontSize: context.fontSizeXl),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.spacingXl),
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(house.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showAddEditHouseSheet(context, houseId: houseId);
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
                            style: TextStyle(color: AppColors.destructive),
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
                      context.go('/');
                    }
                  }
                },
              ),
            ],
          ),
          body: ItemsScreen(houseId: houseId, houseName: house.name),
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
