import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../providers/house_deletion_provider.dart';
import '../model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';

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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 64,
                    color: AppColors.disabled,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nessuna casa',
                    style: TextStyle(fontSize: 18, color: AppColors.disabled),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aggiungi la tua prima casa',
                    style: TextStyle(fontSize: 14, color: AppColors.disabled),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: houses.length,
            itemBuilder: (context, index) {
              final house = houses[index];
              return _HouseCard(house: house);
            },
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

class _HouseCard extends ConsumerWidget {
  final HouseModel house;

  const _HouseCard({required this.house});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        onTap: () {
          context.push('/houses/${house.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppConstants.cardBorderRadius,
                  ),
                ),
                child: Icon(Icons.home, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      house.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (house.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        house.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.destructiveLight,
                ),
                onPressed: () => _showDeleteDialog(context, ref),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    // Verifica se la casa può essere eliminata
    final deletionCheck = await ref.read(
      canDeleteHouseProvider(house.id).future,
    );

    if (!context.mounted) return;

    if (!deletionCheck.canDelete) {
      // Mostra dialogo informativo sul perché non può essere eliminata
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Impossibile eliminare'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(deletionCheck.reason ?? 'La casa non può essere eliminata.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Conferma eliminazione
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina casa'),
        content: Text('Sei sicuro di voler eliminare "${house.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Elimina',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(houseNotifierProvider.notifier).deleteHouse(house.id);
    }
  }
}
