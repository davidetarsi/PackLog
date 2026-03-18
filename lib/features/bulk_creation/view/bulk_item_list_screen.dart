import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../items/model/item_model.dart';
import '../model/draft_item.dart';
import '../providers/bulk_creation_provider.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../../shared/widgets/category_section_header.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_item_tile.dart';
import '../../../shared/widgets/universal_action_bar.dart';
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
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _lastAddedItemId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  void _handleAddManualItem(ItemCategory category) {
    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final newItemId = notifier.addManualItem(category);
    
    setState(() {
      _lastAddedItemId = newItemId;
      _itemKeys[newItemId] = GlobalKey();
    });

    // Auto-scroll e auto-focus dopo il rebuild
    // Usa un delay leggermente più lungo per dare tempo al widget di renderizzarsi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToItem(newItemId);
      });
    });
  }

  void _scrollToItem(String itemId, {int retryCount = 0}) {
    if (!mounted || !_scrollController.hasClients) return;
    
    final key = _itemKeys[itemId];
    if (key?.currentContext == null) {
      // Widget non ancora renderizzato, retry fino a 5 volte
      if (retryCount < 5) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _scrollToItem(itemId, retryCount: retryCount + 1);
        });
      }
      return;
    }

    // Widget trovato: scroll preciso alla sua posizione
    try {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3, // Posiziona l'item al 30% dall'alto dello schermo
      );
    } catch (e) {
      // Fallback silenzioso se ensureVisible fallisce
      debugPrint('Failed to scroll to item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkCreationNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final itemsByCategory = _groupItemsByCategory(state.allItems);

    // Cleanup keys for deleted items
    _itemKeys.removeWhere((id, key) => 
      !state.allItems.any((item) => item.id == id));
    
    // Create keys for new items
    for (final item in state.allItems) {
      _itemKeys.putIfAbsent(item.id, () => GlobalKey());
    }

    return StickyCtaScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bulk-creation/templates/${widget.houseId}'),
        ),
        title: Text('bulk_creation.edit_items'.tr()),
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
              controller: _scrollController,
              padding: EdgeInsets.all(context.spacingMd),
              itemCount: itemsByCategory.keys.length,
              itemBuilder: (context, index) {
                final category = itemsByCategory.keys.elementAt(index);
                final items = itemsByCategory[category]!;

                return _CategorySection(
                  category: category,
                  items: items,
                  itemKeys: _itemKeys,
                  lastAddedItemId: _lastAddedItemId,
                  colorScheme: colorScheme,
                );
              },
            ),
      bottomContent: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CategoryButtonBar(
            onCategorySelected: _handleAddManualItem,
          ),
          SizedBox(height: context.spacingMd),
          UniversalActionBar(
            primaryLabel: 'common.save'.tr(),
            primaryIcon: Icons.save,
            onPrimaryPressed: state.allItems.isNotEmpty && !_isSaving ? _handleSave : null,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Map<ItemCategory, List<DraftItem>> _groupItemsByCategory(List<DraftItem> items) {
    // Usa LinkedHashMap per preservare l'ordine di inserimento
    final Map<ItemCategory, List<DraftItem>> grouped = {};

    // Raggruppa mantenendo l'ordine originale degli item
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    // Ordina le chiavi per categoria (enum index) ma NON gli item dentro
    final sortedMap = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );

    return sortedMap;
  }
}

/// Sezione per una categoria di item con header.
class _CategorySection extends StatelessWidget {
  final ItemCategory category;
  final List<DraftItem> items;
  final Map<String, GlobalKey> itemKeys;
  final String? lastAddedItemId;
  final ColorScheme colorScheme;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.itemKeys,
    required this.lastAddedItemId,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        CategorySectionHeader(category: category),
        SizedBox(height: context.spacingSm),

        // Items in this category
        ...items.map((item) => Padding(
              key: itemKeys[item.id],
              padding: EdgeInsets.only(bottom: context.spacingSm),
              child: BulkItemRow(
                item: item,
                autoFocus: item.id == lastAddedItemId,
              ),
            )),

        SizedBox(height: context.spacingMd),
      ],
    );
  }
}

/// Row per un singolo item con TextField inline stabile.
/// 
/// CRITICAL: Usa StatefulWidget con proprio TextEditingController
/// per evitare rebuild loops e keyboard drop quando lo stato cambia.
class BulkItemRow extends ConsumerStatefulWidget {
  final DraftItem item;
  final bool autoFocus;

  const BulkItemRow({
    super.key,
    required this.item,
    this.autoFocus = false,
  });

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

    // Auto-focus se questo è un item appena aggiunto
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
      });
    }
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

    return UniversalItemTile(
      useListTile: false,
      borderColor: colorScheme.outlineVariant,
      borderWidth: 1,
      title: TextField(
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuantityStepper(
            value: widget.item.quantity,
            onChanged: (delta) {
              notifier.updateQuantity(widget.item.id, delta - widget.item.quantity);
            },
            minValue: 1,
          ),
          SizedBox(width: context.spacingSm),
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
        padding: EdgeInsets.all(context.spacingSm),    
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'bulk_creation.add_manual_item'.tr(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                SizedBox(width: context.spacingXs),
                Expanded(
                  child: _CategoryButton(
                    icon: Icons.devices,
                    label: 'items.category_elettronica'.tr(),
                    onTap: () => onCategorySelected(ItemCategory.elettronica),
                    colorScheme: colorScheme,
                  ),
                ),
                SizedBox(width: context.spacingXs),
                Expanded(
                  child: _CategoryButton(
                    icon: Icons.soap,
                    label: 'items.category_toiletries'.tr(),
                    onTap: () => onCategorySelected(ItemCategory.toiletries),
                    colorScheme: colorScheme,
                  ),
                ),
                SizedBox(width: context.spacingXs),
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
            /* SizedBox(height: context.spacingSm),
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
            ), */
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingMd,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.responsive(20)),
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
