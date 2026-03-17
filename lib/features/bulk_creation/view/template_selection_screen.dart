import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/templates_data.dart';
import '../model/user_gender.dart';
import '../providers/bulk_creation_provider.dart';
import '../../../shared/theme/app_spacing.dart';

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

    final previewItemCount = state.allItems.length;
    final selectedTemplatesCount = state.selectedTemplateKeys.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            notifier.reset();
            context.pop();
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
                childAspectRatio: 0.9,
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
                );
              },
            ),
          ),
        ],
      ),

      // Bottom CTA
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: FilledButton(
            onPressed: previewItemCount > 0
                ? () => context.push('/bulk-creation/items/${widget.houseId}')
                : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: context.spacingMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  previewItemCount > 0
                      ? 'bulk_creation.continue_with_items'.tr(
                          namedArgs: {'count': previewItemCount.toString()},
                        )
                      : 'bulk_creation.select_at_least_one'.tr(),
                ),
                if (selectedTemplatesCount > 0) ...[
                  SizedBox(width: context.spacingSm),
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
                      selectedTemplatesCount.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.all(context.spacingMd),
      child: SegmentedButton<UserGender>(
        segments: [
          ButtonSegment(
            value: UserGender.male,
            label: Text('bulk_creation.gender_male'.tr()),
            icon: const Icon(Icons.man),
          ),
          ButtonSegment(
            value: UserGender.female,
            label: Text('bulk_creation.gender_female'.tr()),
            icon: const Icon(Icons.woman),
          ),
          ButtonSegment(
            value: UserGender.neutral,
            label: Text('bulk_creation.gender_neutral'.tr()),
            icon: const Icon(Icons.person),
          ),
        ],
        selected: {selectedGender},
        onSelectionChanged: (Set<UserGender> selection) {
          onGenderChanged(selection.first);
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primaryContainer;
            }
            return colorScheme.surfaceContainerHighest;
          }),
        ),
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

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      IconData(
                        _getIconCodePoint(template.icon),
                        fontFamily: 'MaterialIcons',
                      ),
                      size: context.responsive(48),
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
}
