import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';

class AddEditItemScreen extends ConsumerStatefulWidget {
  /// houseId è opzionale: se null, viene mostrato un dropdown per selezionare la casa
  final String? houseId;
  final String? itemId;
  /// Callback opzionale chiamato quando l'item viene salvato con successo
  final void Function(String itemId, String houseId)? onItemSaved;

  const AddEditItemScreen({super.key, this.houseId, this.itemId, this.onItemSaved});

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ItemCategory _selectedCategory = ItemCategory.vestiti;
  int _selectedQuantity = 1;
  bool _isLoading = false;
  String? _selectedHouseId;

  // Lista di valori per la quantità
  static const List<int> _quantityOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 50, 100];

  bool get _needsHouseSelection => widget.houseId == null;

  @override
  void initState() {
    super.initState();
    _selectedHouseId = widget.houseId;
    if (widget.itemId != null && widget.houseId != null) {
      _loadItem();
    }
  }

  Future<void> _loadItem() async {
    if (_selectedHouseId == null) return;
    final itemsAsync = ref.watch(itemNotifierProvider(_selectedHouseId!));
    itemsAsync.whenData((items) {
      final item = items.firstWhere(
        (i) => i.id == widget.itemId,
        orElse: () => throw StateError('Oggetto non trovato'),
      );
      _nameController.text = item.name;
      _descriptionController.text = item.description ?? '';
      _selectedQuantity = item.quantity ?? 1;
      _selectedCategory = item.category;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showQuantityPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Seleziona quantità',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _quantityOptions.length,
              itemBuilder: (context, index) {
                final quantity = _quantityOptions[index];
                return ListTile(
                  title: Text(quantity.toString()),
                  trailing: _selectedQuantity == quantity
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(context, quantity),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (selected != null) {
      setState(() => _selectedQuantity = selected);
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      // Verifica che sia selezionata una casa
      if (_selectedHouseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona una casa')),
        );
        return;
      }

      setState(() => _isLoading = true);
      
      final now = DateTime.now();
      final quantity = _selectedQuantity;
      final houseId = _selectedHouseId!;
      final itemId = widget.itemId ?? const Uuid().v4();
      
      final item = widget.itemId != null
          ? (() {
              final itemsAsync = ref.read(itemNotifierProvider(houseId));
              final items = itemsAsync.value;
              if (items == null) {
                throw StateError('Oggetto non trovato');
              }
              return items.firstWhere((i) => i.id == widget.itemId).copyWith(
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                    category: _selectedCategory,
                    quantity: quantity,
                    updatedAt: now,
                  );
            })()
          : ItemModel(
              id: itemId,
              houseId: houseId,
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              category: _selectedCategory,
              quantity: quantity,
              createdAt: now,
              updatedAt: now,
            );

      try {
        if (widget.itemId != null) {
          await ref.read(itemNotifierProvider(houseId).notifier).updateItem(item);
        } else {
          await ref.read(itemNotifierProvider(houseId).notifier).addItem(item);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // Chiama il callback se presente
        widget.onItemSaved?.call(item.id, houseId);
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemId != null ? 'Modifica oggetto' : 'Nuovo oggetto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selezione casa (solo se houseId non è fornito)
            if (_needsHouseSelection) ...[
              housesAsync.when(
                data: (houses) => _buildHouseSelector(houses),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Errore: $e'),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il nome è obbligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ItemCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria *',
                border: OutlineInputBorder(),
              ),
              items: ItemCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _showQuantityPicker,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Quantità',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedQuantity.toString(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveItem,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.itemId != null ? 'Salva' : 'Crea'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseSelector(List<HouseModel> houses) {
    if (houses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nessuna casa disponibile. Crea prima una casa.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _showHousePicker(houses),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Casa *',
          border: const OutlineInputBorder(),
          errorText: _selectedHouseId == null ? null : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedHouseId != null
                  ? houses.firstWhere(
                      (h) => h.id == _selectedHouseId,
                      orElse: () => houses.first,
                    ).name
                  : 'Seleziona una casa',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _selectedHouseId == null ? Colors.grey : null,
                  ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _showHousePicker(List<HouseModel> houses) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Seleziona casa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: houses.length,
              itemBuilder: (context, index) {
                final house = houses[index];
                return ListTile(
                  leading: const Icon(Icons.home),
                  title: Text(house.name),
                  subtitle: house.description != null ? Text(house.description!) : null,
                  trailing: _selectedHouseId == house.id
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(context, house.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (selected != null) {
      setState(() => _selectedHouseId = selected);
    }
  }
}

