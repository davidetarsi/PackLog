import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../items/model/item_model.dart';
import '../model/draft_item.dart';
import '../providers/bulk_creation_provider.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
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

  /// Mappa id → GlobalKey per il posizionamento scroll.
  final Map<String, GlobalKey> _itemKeys = {};

  /// Mappa id → FocusNode gestita dal parent per evitare il race condition
  /// tastiera/scroll. Il parent chiama requestFocus() solo DOPO che
  /// l'animazione di scroll è completata (await _scrollToItem).
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    _scrollController.dispose();
    // Dispone tutti i FocusNode rimasti (caso di uscita dalla schermata
    // senza che il build li abbia già rimossi).
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final navigator = GoRouter.of(context);

    // Il conteggio è catturato DENTRO l'operation per due motivi:
    // 1. saveToDatabase() chiama reset() al termine, azzerando lo stato.
    // 2. In caso di retry, la variabile viene re-acquisita dallo stato aggiornato,
    //    evitando di mostrare il conteggio di un tentativo precedente.
    // Usiamo totalItemsCount (somma delle quantità) e non allItems.length
    // (tipi distinti): se l'utente aggiunge 1 item con quantità 5, il
    // messaggio deve dire "5 oggetti aggiunti", non "1 oggetto aggiunto".
    int savedCount = 0;

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        savedCount =
            ref.read(bulkCreationNotifierProvider).totalItemsCount;
        await notifier.saveToDatabase();
      },
      errorTitle: 'common.error'.tr(),
      errorMessage: 'bulk_creation.save_failed'.tr(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      AppSnackBar.showSuccess(
        context,
        'bulk_creation.save_success'.tr(
          namedArgs: {'count': savedCount.toString()},
        ),
      );

      // Ricostruisce lo stack: root (lista case) + dettaglio casa in cima.
      // go('/') resetta lo stack alla shell; il push va nel frame successivo
      // perché GoRouter processa go() con una rebuild asincrona che
      // sovrascriverebbe un push() chiamato nello stesso microtask.
      final houseId = widget.houseId;
      navigator.go('/');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.push('/houses/$houseId');
      });
    }
  }

  /// Aggiunge un item manuale, richiede il focus immediatamente nel frame
  /// successivo, e poi scorre per centrarlo dopo l'apertura della tastiera.
  ///
  /// ## Sequenza (zero lag percepito)
  ///
  /// ```
  /// frame+1   requestFocus()  →  tastiera inizia ad aprirsi
  /// +400 ms   _scrollToItemWhenKeyboardOpens()  →  schermo stabile, scroll
  /// ```
  ///
  /// Richiedere il focus prima dello scroll elimina il lag percepito:
  /// l'utente vede il cursore lampeggiare istantaneamente. Lo scroll avviene
  /// dopo che la tastiera ha ridimensionato la viewport (≈300-400 ms),
  /// così `ensureVisible` lavora sulle dimensioni finali e non va in conflitto
  /// con il resize.
  void _handleAddManualItem(ItemCategory category) {
    final notifier = ref.read(bulkCreationNotifierProvider.notifier);
    final newItemId = notifier.addManualItem(category);

    setState(() {
      _itemKeys.putIfAbsent(newItemId, () => GlobalKey());
      _focusNodes.putIfAbsent(newItemId, () => FocusNode());
    });

    // Frame successivo: il widget è nel layout tree (Column eager-renderizza
    // tutto), quindi il context è disponibile immediatamente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[newItemId]?.requestFocus();
        _scrollToItemWhenKeyboardOpens(newItemId);
      }
    });
  }

  /// Scorre fino all'item dopo che la tastiera ha aperto e stabilizzato la
  /// viewport (≈400 ms).
  ///
  /// Con `SingleChildScrollView + Column` tutti i widget sono già nel layout
  /// tree, quindi non servono retry: il context è sempre disponibile.
  void _scrollToItemWhenKeyboardOpens(String itemId) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final key = _itemKeys[itemId];
      if (key?.currentContext != null) {
        try {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          );
        } catch (e) {
          debugPrint('[BulkItemListScreen] scroll fallito: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkCreationNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final itemsByCategory = _groupItemsByCategory(state.allItems);

    // Rimuove key e focusNode per item eliminati, disponendo i FocusNode.
    _itemKeys.removeWhere(
      (id, _) => !state.allItems.any((item) => item.id == id),
    );
    _focusNodes.removeWhere((id, node) {
      if (!state.allItems.any((item) => item.id == id)) {
        node.dispose();
        return true;
      }
      return false;
    });

    // Crea key e focusNode per item nuovi (idempotente grazie a putIfAbsent).
    for (final item in state.allItems) {
      _itemKeys.putIfAbsent(item.id, () => GlobalKey());
      _focusNodes.putIfAbsent(item.id, () => FocusNode());
    }

    return StickyCtaScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
          // SingleChildScrollView + Column invece di ListView.builder:
          // tutti i widget sono renderizzati subito (eager), garantendo che
          // i GlobalKey context siano disponibili nel frame successivo a
          // setState. ListView.builder non renderizza gli item fuori schermo,
          // causando fallimenti dei lookup di GlobalKey e retry inutili.
          // Il numero di categorie è piccolo (≤ 4), quindi non ci sono
          // problemi di performance con il rendering eager.
          : SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(context.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: itemsByCategory.entries.map((entry) {
                  return _CategorySection(
                    category: entry.key,
                    items: entry.value,
                    itemKeys: _itemKeys,
                    focusNodes: _focusNodes,
                    colorScheme: colorScheme,
                  );
                }).toList(),
              ),
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
            onPrimaryPressed:
                state.allItems.isNotEmpty && !_isSaving ? _handleSave : null,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Map<ItemCategory, List<DraftItem>> _groupItemsByCategory(
      List<DraftItem> items) {
    final Map<ItemCategory, List<DraftItem>> grouped = {};

    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    // Ordina per enum index, non per ordine di inserimento nella mappa.
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategorySection
// ---------------------------------------------------------------------------

/// Sezione per una categoria di item con header.
class _CategorySection extends StatelessWidget {
  final ItemCategory category;
  final List<DraftItem> items;
  final Map<String, GlobalKey> itemKeys;

  /// FocusNode per ogni item, gestiti dal parent per il sequenziamento
  /// scroll → focus.
  final Map<String, FocusNode> focusNodes;
  final ColorScheme colorScheme;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.itemKeys,
    required this.focusNodes,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategorySectionHeader(category: category),
        SizedBox(height: context.spacingSm),

        ...items.map((item) => Padding(
              key: itemKeys[item.id],
              padding: EdgeInsets.only(bottom: context.spacingSm),
              child: BulkItemRow(
                item: item,
                focusNode: focusNodes[item.id]!,
              ),
            )),

        SizedBox(height: context.spacingMd),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BulkItemRow
// ---------------------------------------------------------------------------

/// Row per un singolo item con TextField inline stabile.
///
/// ## Gestione focus
///
/// Il [focusNode] viene passato dal parent (`_BulkItemListScreenState`) e
/// viene chiamato da lì **dopo** la fine dell'animazione di scroll.
/// `BulkItemRow` NON gestisce l'auto-focus: è responsabilità esclusiva del
/// parent sequenzializzare scroll → focus per evitare il race condition con
/// il resize della tastiera.
///
/// ## CRITICAL: TextField stabile
///
/// Usa StatefulWidget con proprio TextEditingController per evitare rebuild
/// loops e keyboard drop quando lo stato Riverpod cambia.
class BulkItemRow extends ConsumerStatefulWidget {
  final DraftItem item;

  /// FocusNode fornito e gestito dal parent. NON viene disposto qui.
  final FocusNode focusNode;

  const BulkItemRow({
    super.key,
    required this.item,
    required this.focusNode,
  });

  @override
  ConsumerState<BulkItemRow> createState() => _BulkItemRowState();
}

class _BulkItemRowState extends ConsumerState<BulkItemRow> {
  late TextEditingController _controller;
  String _lastCommittedName = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.name);
    _lastCommittedName = widget.item.name;

    // CRITICAL: aggiorna il provider solo quando il focus viene perso,
    // non ad ogni keystroke. Previene rebuild loops e keyboard drop.
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(BulkItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Migra il listener se il focusNode cambia (raro ma difensivo).
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    // CRITICAL: aggiorna il controller SOLO se l'item.name è cambiato
    // da una fonte esterna (non dall'utente che sta digitando).
    // Previene il salto del cursore durante la digitazione.
    if (widget.item.name != oldWidget.item.name &&
        widget.item.name != _controller.text) {
      _controller.text = widget.item.name;
      _lastCommittedName = widget.item.name;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    // NON disponiamo widget.focusNode: è di proprietà del parent.
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) {
      final newName = _controller.text.trim();
      if (newName.isNotEmpty && newName != _lastCommittedName) {
        ref.read(bulkCreationNotifierProvider.notifier).renameItem(
              widget.item.id,
              newName,
            );
        _lastCommittedName = newName;
      } else if (newName.isEmpty) {
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
    widget.focusNode.unfocus();
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
        focusNode: widget.focusNode,
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
              notifier.updateQuantity(
                  widget.item.id, delta - widget.item.quantity);
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

// ---------------------------------------------------------------------------
// _CategoryButtonBar
// ---------------------------------------------------------------------------

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
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategoryButton
// ---------------------------------------------------------------------------

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
