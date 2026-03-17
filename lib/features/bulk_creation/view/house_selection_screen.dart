import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../houses/providers/house_provider.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/theme/app_spacing.dart';

/// Schermata intermedia per selezionare la casa di destinazione
/// prima di accedere ai template di creazione massiva.
class HouseSelectionScreen extends ConsumerWidget {
  const HouseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(houseNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text('bulk_creation.select_house'.tr()),
      ),
      body: housesAsync.when(
        data: (houses) {
          if (houses.isEmpty) {
            return EmptyState(
              icon: Icons.home_outlined,
              title: 'houses.no_houses'.tr(),
              subtitle: 'houses.create_first_house'.tr(),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(context.spacingMd),
            itemCount: houses.length,
            separatorBuilder: (_, index) => SizedBox(height: context.spacingSm),
            itemBuilder: (context, index) {
              final house = houses[index];
              return _HouseCard(
                houseId: house.id,
                houseName: house.name,
                iconName: house.iconName,
                isPrimary: house.isPrimary,
                colorScheme: colorScheme,
                onTap: () {
                  context.push('/bulk-creation/templates/${house.id}');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => EmptyState(
          icon: Icons.error_outline,
          title: 'common.error'.tr(),
          subtitle: err.toString(),
        ),
      ),
    );
  }
}

class _HouseCard extends StatelessWidget {
  final String houseId;
  final String houseName;
  final String iconName;
  final bool isPrimary;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _HouseCard({
    required this.houseId,
    required this.houseName,
    required this.iconName,
    required this.isPrimary,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.responsiveBorderRadius(12),
        child: Container(
          padding: EdgeInsets.all(context.spacingMd),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: context.responsiveBorderRadius(12),
          ),
          child: Row(
            children: [
              Icon(
                HouseIcons.getIcon(iconName),
                size: context.responsive(32),
                color: colorScheme.primary,
              ),
              SizedBox(width: context.spacingMd),
              Expanded(
                child: Text(
                  houseName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (isPrimary)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacingSm,
                    vertical: context.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: context.responsiveBorderRadius(8),
                  ),
                  child: Text(
                    'houses.primary'.tr(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              SizedBox(width: context.spacingSm),
              Icon(
                Icons.arrow_forward_ios,
                size: context.responsive(16),
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
