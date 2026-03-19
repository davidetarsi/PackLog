import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/templates_data.dart';
import '../model/user_gender.dart';
import '../providers/bulk_creation_provider.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../items/model/item_model.dart';

/// Schermata di selezione dei template di viaggio.
/// 
/// Permette all'utente di:
/// - Selezionare il genere per filtrare gli item
/// - Selezionare uno o più template di viaggio
/// - Visualizzare un'anteprima del conteggio item
class TemplateSelectionScreen extends ConsumerStatefulWidget {
  final String houseId;

  const TemplateSelectionScreen({super.key, required this.houseId});

  @override
  ConsumerState<TemplateSelectionScreen> createState() =>
      _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState
    extends ConsumerState<TemplateSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Imposta la casa di destinazione all'avvio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bulkCreationNotifierProvider.notifier).setTargetHouse(widget.houseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkCreationNotifierProvider);
    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final previewItemCount = state.totalItemsCount;
    final selectedTemplatesCount = state.selectedTemplateKeys.length;

    return StickyCtaScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            notifier.reset();
            context.go('/houses/${widget.houseId}');
          },
        ),
        title: Text('bulk_creation.select_templates'.tr()),
      ),
      body: Column(
        children: [
          // Gender Picker (Segmented Control)
          _GenderPicker(
            selectedGender: state.gender,
            onGenderChanged: (gender) => notifier.setGender(gender),
          ),

          // Template Grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(context.spacingMd),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                mainAxisSpacing: context.spacingMd,
                crossAxisSpacing: context.spacingMd,
              ),
              itemCount: kTravelTemplates.length,
              itemBuilder: (context, index) {
                final template = kTravelTemplates[index];
                final isSelected = state.selectedTemplateKeys.contains(template.key);

                return _TemplateCard(
                  template: template,
                  isSelected: isSelected,
                  onTap: () => notifier.toggleTemplate(template.key),
                  colorScheme: colorScheme,
                  selectedGender: state.gender,
                );
              },
            ),
          ),
        ],
      ),
      bottomContent: UniversalActionBar(
        primaryLabel: selectedTemplatesCount > 0
            ? 'bulk_creation.continue_with_items'.tr(
                namedArgs: {'count': previewItemCount.toString()},
              )
            : 'bulk_creation.continue_without_templates'.tr(),
        //primaryIcon: Icons.arrow_forward,
        onPrimaryPressed: () => context.push('/bulk-creation/items/${widget.houseId}'),
      ),
    );
  }
}

/// Widget per la selezione del genere (Uomo, Donna, Neutro).
class _GenderPicker extends StatelessWidget {
  final UserGender selectedGender;
  final ValueChanged<UserGender> onGenderChanged;

  const _GenderPicker({
    required this.selectedGender,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.spacingMd),
      alignment: Alignment.center,
      child: AppPillTab<UserGender>(
        items: UserGender.values,
        selectedItem: selectedGender,
        getLabel: (gender) {
          switch (gender) {
            case UserGender.male:
              return 'bulk_creation.gender_male'.tr();
            case UserGender.female:
              return 'bulk_creation.gender_female'.tr();
            case UserGender.neutral:
              return 'bulk_creation.gender_neutral'.tr();
          }
        },
        getIcon: (gender) {
          switch (gender) {
            case UserGender.male:
              return const Icon(Icons.man, size: 16);
            case UserGender.female:
              return const Icon(Icons.woman, size: 16);
            case UserGender.neutral:
              return const Icon(Icons.person, size: 16);
          }
        },
        onSelected: onGenderChanged,
        scrollPadding: EdgeInsets.symmetric(horizontal: context.spacingMd),
      ),
    );
  }
}

/// Card per rappresentare un template di viaggio.
class _TemplateCard extends StatelessWidget {
  final dynamic template;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final UserGender selectedGender;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.selectedGender,
  });

  @override
  Widget build(BuildContext context) {
    final categoryCounts = template.getCategoryCountsByGender(selectedGender);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.responsiveBorderRadius(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: context.responsiveBorderRadius(16),
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(context.spacingMd),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          IconData(
                            _getIconCodePoint(template.icon),
                            fontFamily: 'MaterialIcons',
                          ),
                          size: context.responsive(40),
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(height: context.spacingSm),
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.spacingXs),
                        Text(
                          template.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    
                    // Category badges in 2x2 grid
                    _buildCategoryBadgesGrid(context, categoryCounts),
                  ],
                ),
              ),

              // Checkmark indicator
              if (isSelected)
                Positioned(
                  top: context.spacingSm,
                  right: context.spacingSm,
                  child: Container(
                    padding: EdgeInsets.all(context.spacingXs),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: context.responsive(16),
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadgesGrid(BuildContext context, Map<ItemCategory, int> categoryCounts) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCategoryBadge(context, ItemCategory.vestiti, categoryCounts[ItemCategory.vestiti] ?? 0),
            ),
            SizedBox(width: context.spacingXs),
            Expanded(
              child: _buildCategoryBadge(context, ItemCategory.toiletries, categoryCounts[ItemCategory.toiletries] ?? 0),
            ),
          ],
        ),
        SizedBox(height: context.spacingXs),
        Row(
          children: [
            Expanded(
              child: _buildCategoryBadge(context, ItemCategory.elettronica, categoryCounts[ItemCategory.elettronica] ?? 0),
            ),
            SizedBox(width: context.spacingXs),
            Expanded(
              child: _buildCategoryBadge(context, ItemCategory.varie, categoryCounts[ItemCategory.varie] ?? 0),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryBadge(BuildContext context, ItemCategory category, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingXs,
        vertical: context.spacingXs,
      ),
      decoration: BoxDecoration(
        color: count > 0 
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.1)  //it was 0.8
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),  //it was 0.3
        borderRadius: context.responsiveBorderRadius(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(category),
            size: context.responsive(16),
            color: count > 0
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(width: 4),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: count > 0
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  int _getIconCodePoint(String iconName) {
    final iconMap = {
      'weekend': Icons.weekend.codePoint,
      'flight': Icons.flight.codePoint,
      'business_center': Icons.business_center.codePoint,
      'laptop_mac': Icons.laptop_mac.codePoint,
      'beach_access': Icons.beach_access.codePoint,
      'terrain': Icons.terrain.codePoint,
    };
    return iconMap[iconName] ?? Icons.card_travel.codePoint;
  }

  IconData _getCategoryIcon(ItemCategory category) {
    switch (category) {
      case ItemCategory.vestiti:
        return Icons.checkroom;
      case ItemCategory.toiletries:
        return Icons.soap;
      case ItemCategory.elettronica:
        return Icons.devices;
      case ItemCategory.varie:
        return Icons.category;
    }
  }
}
