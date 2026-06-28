import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/design_system.dart';
import '../theme/app_spacing.dart';
import 'skeleton/skeleton.dart';
import 'universal_action_bar.dart';

/// Bottom sheet generico per gestire una lista di entità persistenti.
///
/// Consolida [LuggagesManagementSheet] e [SpacesManagementSheet] che
/// condividevano la stessa struttura layout. I callback [onEdit], [onDelete],
/// [onAdd] incapsulano l'intera logica specifica dell'entità (navigazione,
/// dialog di conferma, invalidazione provider) mantenendo il widget
/// agnostico rispetto al tipo T.
///
/// Esempio minimo:
/// ```dart
/// EntityManagementSheet<LuggageModel>(
///   title: 'luggages.title'.tr(),
///   watch: (ref) => ref.watch(luggageNotifierProvider(houseId)),
///   getIcon: (_) => Icons.luggage,
///   getName: (l) => l.name,
///   getSubtitle: (l) => l.sizeDescription,
///   onEdit: _onEdit,
///   onDelete: _onDelete,
///   onRetry: (ref) => ref.invalidate(luggageNotifierProvider(houseId)),
///   addLabel: 'luggages.add_new'.tr(),
///   onAdd: (ctx, ref) => showAddEditLuggageSheet(ctx, houseId: houseId),
///   emptyIcon: Icons.luggage_outlined,
///   emptyTitle: 'luggages.no_luggages'.tr(),
///   emptySubtitle: 'luggages.no_luggages_subtitle'.tr(),
/// )
/// ```
class EntityManagementSheet<T> extends ConsumerWidget {
  final String title;
  final AsyncValue<List<T>> Function(WidgetRef ref) watch;
  final IconData Function(T item) getIcon;
  final String Function(T item) getName;
  final String? Function(T item)? getSubtitle;
  final Future<void> Function(BuildContext context, WidgetRef ref, T item)
  onEdit;
  final Future<void> Function(BuildContext context, WidgetRef ref, T item)
  onDelete;
  final void Function(WidgetRef ref) onRetry;
  final String addLabel;
  final Future<void> Function(BuildContext context, WidgetRef ref) onAdd;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const EntityManagementSheet({
    super.key,
    required this.title,
    required this.watch,
    required this.getIcon,
    required this.getName,
    this.getSubtitle,
    required this.onEdit,
    required this.onDelete,
    required this.onRetry,
    required this.addLabel,
    required this.onAdd,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemsAsync = watch(ref);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.responsive(20)),
        ),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const DsBottomSheetHandle(),
          Padding(
            padding: context.responsiveScreenPadding,
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: context.iconSizeMd),
                ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return DsEmptyState(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtitle = getSubtitle?.call(item);
                    return Card(
                      margin: EdgeInsets.only(bottom: context.spacingSm),
                      elevation: 0,
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: context.responsiveBorderRadius(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Icon(
                          getIcon(item),
                          color: colorScheme.primary,
                          size: context.iconSizeMd,
                        ),
                        title: Text(getName(item)),
                        subtitle: subtitle != null ? Text(subtitle) : null,
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            switch (value) {
                              case 'edit':
                                await onEdit(context, ref, item);
                              case 'delete':
                                await onDelete(context, ref, item);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit),
                                  const SizedBox(width: 12),
                                  Text('common.edit'.tr()),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete),
                                  const SizedBox(width: 12),
                                  Text('common.delete'.tr()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const SkeletonSimpleList(),
              error: (error, stack) =>
                  DsErrorState(error: error, onRetry: () => onRetry(ref)),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: context.spacingMd,
                right: context.spacingMd,
                top: context.spacingMd,
                bottom: context.spacingSm,
              ),
              child: UniversalActionBar(
                primaryLabel: addLabel,
                primaryIcon: Icons.add,
                onPrimaryPressed: () => onAdd(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
