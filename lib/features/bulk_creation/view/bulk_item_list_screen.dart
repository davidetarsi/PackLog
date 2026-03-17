import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../items/model/item_model.dart';
import '../model/draft_item.dart';
import '../providers/bulk_creation_provider.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/theme/app_spacing.dart';

/// Schermata di editing massivo degli item aggregati dai template.
/// 
/// Permette all'utente di:
/// - Rinominare item inline (TextField stabile)
/// - Modificare quantità con pulsanti +/-
/// - Eliminare item non desiderati
/// - Aggiungere item manuali per categoria
class BulkItemListScreen extends ConsumerStatefulWidget {
  final String houseId;

  const BulkItemListScreen({super.key, required this.houseId});

  @override
  ConsumerState<BulkItemListScreen> createState() => _BulkItemListScreenState();
}

class _BulkItemListScreenState extends ConsumerState<BulkItemListScreen> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => notifier.saveToDatabase(),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'bulk_creation.save_failed'.tr(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      final itemCount = ref.read(bulkCreationNotifierProvider).allItems.length;
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('bulk_creation.save_success'.tr(
            namedArgs: {'count': itemCount.toString()},
          )),
        ),
      );

      // Naviga indietro alla schermata della casa
      navigator.go('/houses/${widget.houseId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkCreationNotifierProvider);
    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final itemsByCategory = _groupItemsByCategory(state.allItems);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('bulk_creation.edit_items'.tr()),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: SizedBox(
                width: context.responsive(24),
                height: context.responsive(24),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: state.allItems.isNotEmpty ? _handleSave : null,
            ),
        ],
      ),
      body: state.allItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: context.responsive(64),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: context.spacingMd),
                  Text(
                    'bulk_creation.no_items'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(context.spacingMd),
              itemCount: itemsByCategory.keys.length,
              itemBuilder: (context, index) {
                final category = itemsByCategory.keys.elementAt(index);
                final items = itemsByCategory[category]!;

                return _CategorySection(
                  category: category,
                  items: items,
                  colorScheme: colorScheme,
                );
              },
            ),

      // Bottom bar with category buttons
      bottomNavigationBar: _CategoryButtonBar(
        onCategorySelected: (category) => notifier.addManualItem(category),
      ),
    );
  }

  Map<ItemCategory, List<DraftItem>> _groupItemsByCategory(List<DraftItem> items) {
    final Map<ItemCategory, List<DraftItem>> grouped = {};

    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return grouped;
  }
}

/// Sezione per una categoria di item con header.
class _CategorySection extends StatelessWidget {
  final ItemCategory category;
  final List<DraftItem> items;
  final ColorScheme colorScheme;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacingSm,
            vertical: context.spacingXs,
          ),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                size: context.responsive(20),
                color: colorScheme.primary,
              ),
              SizedBox(width: context.spacingSm),
              Text(
                _getCategoryName(category),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.spacingSm),

        // Items in this category
        ...items.map((item) => Padding(
              padding: EdgeInsets.only(bottom: context.spacingSm),
              child: BulkItemRow(item: item),
            )),

        SizedBox(height: context.spacingMd),
      ],
    );
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

  String _getCategoryName(ItemCategory category) {
    switch (category) {
      case ItemCategory.vestiti:
        return 'items.category_vestiti'.tr();
      case ItemCategory.toiletries:
        return 'items.category_toiletries'.tr();
      case ItemCategory.elettronica:
        return 'items.category_elettronica'.tr();
      case ItemCategory.varie:
        return 'items.category_varie'.tr();
    }
  }
}

/// Row per un singolo item con TextField inline stabile.
/// 
/// CRITICAL: Usa StatefulWidget con proprio TextEditingController
/// per evitare rebuild loops e keyboard drop quando lo stato cambia.
class BulkItemRow extends ConsumerStatefulWidget {
  final DraftItem item;

  const BulkItemRow({super.key, required this.item});

  @override
  ConsumerState<BulkItemRow> createState() => _BulkItemRowState();
}

class _BulkItemRowState extends ConsumerState<BulkItemRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String _lastCommittedName = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.name);
    _lastCommittedName = widget.item.name;
    _focusNode = FocusNode();

    // CRITICAL: Solo quando l'utente finisce di editare (perde focus)
    // chiamiamo il notifier. Questo previene rebuild loops e keyboard drop.
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(BulkItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Aggiorna il controller SOLO se l'item.name è cambiato
    // da una fonte esterna (non dall'utente che sta digitando).
    // Questo previene che il cursore salti durante la digitazione.
    if (widget.item.name != oldWidget.item.name &&
        widget.item.name != _controller.text) {
      _controller.text = widget.item.name;
      _lastCommittedName = widget.item.name;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Focus perso: committa il nuovo nome se è cambiato
      final newName = _controller.text.trim();
      if (newName.isNotEmpty && newName != _lastCommittedName) {
        ref.read(bulkCreationNotifierProvider.notifier).renameItem(
              widget.item.id,
              newName,
            );
        _lastCommittedName = newName;
      } else if (newName.isEmpty) {
        // Nome vuoto: ripristina il nome precedente
        _controller.text = _lastCommittedName;
      }
    }
  }

  void _onSubmitted(String value) {
    final newName = value.trim();
    if (newName.isNotEmpty && newName != _lastCommittedName) {
      ref.read(bulkCreationNotifierProvider.notifier).renameItem(
            widget.item.id,
            newName,
          );
      _lastCommittedName = newName;
    } else if (newName.isEmpty) {
      _controller.text = _lastCommittedName;
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
        borderRadius: context.responsiveBorderRadius(12),
      ),
      child: Row(
        children: [
          // Name TextField (inline editing)
          Expanded(
            flex: 3,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.spacingSm,
                  vertical: context.spacingXs,
                ),
                hintText: 'bulk_creation.item_name_hint'.tr(),
              ),
              onSubmitted: _onSubmitted,
            ),
          ),

          SizedBox(width: context.spacingSm),

          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: widget.item.quantity > 1
                    ? () => notifier.updateQuantity(widget.item.id, -1)
                    : null,
                iconSize: context.responsive(24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(width: context.spacingXs),
              Container(
                constraints: BoxConstraints(minWidth: context.responsive(32)),
                alignment: Alignment.center,
                child: Text(
                  widget.item.quantity.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SizedBox(width: context.spacingXs),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => notifier.updateQuantity(widget.item.id, 1),
                iconSize: context.responsive(24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          SizedBox(width: context.spacingSm),

          // Delete button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => notifier.deleteItem(widget.item.id),
            iconSize: context.responsive(20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            color: colorScheme.error,
          ),
        ],
      ),
    );
  }
}

/// Barra inferiore con pulsanti per aggiungere item per categoria.
class _CategoryButtonBar extends ConsumerWidget {
  final ValueChanged<ItemCategory> onCategorySelected;

  const _CategoryButtonBar({required this.onCategorySelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(context.spacingMd),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'bulk_creation.add_manual_item'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: context.spacingSm),
            Row(
              children: [
                Expanded(
                  child: _CategoryButton(
                    icon: Icons.checkroom,
                    label: 'items.category_vestiti'.tr(),
                    onTap: () => onCategorySelected(ItemCategory.vestiti),
                    colorScheme: colorScheme,
                  ),
                ),
                SizedBox(width: context.spacingSm),
                Expanded(
                  child: _CategoryButton(
                    icon: Icons.devices,
                    label: 'items.category_elettronica'.tr(),
                    onTap: () => onCategorySelected(ItemCategory.elettronica),
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacingSm),
            Row(
              children: [
                Expanded(
                  child: _CategoryButton(
                    icon: Icons.soap,
                    label: 'items.category_toiletries'.tr(),
                    onTap: () => onCategorySelected(ItemCategory.toiletries),
                    colorScheme: colorScheme,
                  ),
                ),
                SizedBox(width: context.spacingSm),
                Expanded(
                  child: _CategoryButton(
                    icon: Icons.category,
                    label: 'items.category_varie'.tr(),
                    onTap: () => onCategorySelected(ItemCategory.varie),
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsante per una categoria di item.
class _CategoryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _CategoryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingMd,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.responsive(24)),
          SizedBox(height: context.spacingXs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
