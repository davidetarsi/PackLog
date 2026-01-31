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
            return Center(
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
                    'Nessuna casa',
                    style: TextStyle(
                      fontSize: context.fontSizeXl,
                      color: AppColors.disabled,
                    ),
                  ),
                  SizedBox(height: context.spacingSm),
                  Text(
                    'Aggiungi la tua prima casa',
                    style: TextStyle(
                      fontSize: context.fontSizeMd,
                      color: AppColors.disabled,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              bottom: AppConstants.floatingNavBarPadding,
            ),
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

class _HouseCard extends ConsumerWidget {
  final HouseModel house;

  const _HouseCard({required this.house});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: context.responsiveSymmetricPadding(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius,
        ),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius,
        ),
        onTap: () {
          context.push('/houses/${house.id}');
        },
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.spacingSm + 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: context.responsiveBorderRadius(
                    AppConstants.cardBorderRadius,
                  ),
                ),
                child: Icon(
                  Icons.home,
                  color: colorScheme.onPrimaryContainer,
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
                    ),
                    if (house.description != null) ...[
                      SizedBox(height: context.spacingXs),
                      Text(
                        house.description!,
                        style: TextStyle(
                          fontSize: context.fontSizeSm + 1,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                  size: context.iconSizeMd,
                ),
                onPressed: () => _showDeleteDialog(context, ref),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                size: context.iconSizeMd,
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
        builder: (dialogContext) => AlertDialog(
          title: const Text('Impossibile eliminare'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: dialogContext.iconSizeXl,
              ),
              SizedBox(height: dialogContext.spacingMd),
              Text(deletionCheck.reason ?? 'La casa non può essere eliminata.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
