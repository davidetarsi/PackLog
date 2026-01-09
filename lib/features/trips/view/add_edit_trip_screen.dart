import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/providers/item_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/view/add_edit_item_screen.dart';

class AddEditTripScreen extends ConsumerStatefulWidget {
  final String? tripId;

  const AddEditTripScreen({super.key, this.tripId});

  @override
  ConsumerState<AddEditTripScreen> createState() => _AddEditTripScreenState();
}

class _AddEditTripScreenState extends ConsumerState<AddEditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<TripItem> _selectedItems = [];
  bool _isLoading = false;
  
  // Nuovi campi per date e casa destinazione
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;

  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) {
      _loadTrip();
    }
  }

  Future<void> _loadTrip() async {
    final tripsAsync = ref.read(tripNotifierProvider);
    tripsAsync.whenData((trips) {
      final trip = trips.firstWhere(
        (t) => t.id == widget.tripId,
        orElse: () => throw StateError('Lista non trovata'),
      );
      _nameController.text = trip.name;
      _descriptionController.text = trip.description ?? '';
      setState(() {
        _selectedItems = List.from(trip.items);
        _departureDateTime = trip.departureDateTime;
        _returnDateTime = trip.returnDateTime;
        _destinationHouseId = trip.destinationHouseId;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDepartureDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Seleziona data di partenza',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _departureDateTime != null 
          ? TimeOfDay.fromDateTime(_departureDateTime!)
          : TimeOfDay.now(),
      helpText: 'Seleziona ora di partenza',
    );
    if (time == null || !mounted) return;

    setState(() {
      _departureDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _pickReturnDateTime() async {
    final initialDate = _returnDateTime ?? _departureDateTime ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _departureDateTime ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Seleziona data di ritorno',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _returnDateTime != null 
          ? TimeOfDay.fromDateTime(_returnDateTime!)
          : TimeOfDay.now(),
      helpText: 'Seleziona ora di ritorno',
    );
    if (time == null || !mounted) return;

    setState(() {
      _returnDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Non impostata';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveTrip() async {
    if (_formKey.currentState!.validate()) {
      // Validazione date
      if (_departureDateTime != null && _returnDateTime != null) {
        if (_returnDateTime!.isBefore(_departureDateTime!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La data di ritorno deve essere dopo la partenza')),
          );
          return;
        }
      }

      setState(() => _isLoading = true);

      final now = DateTime.now();
      final trip = widget.tripId != null
          ? (() {
              final tripsAsync = ref.read(tripNotifierProvider);
              final trips = tripsAsync.value;
              if (trips == null) {
                throw StateError('Lista non trovata');
              }
              return trips.firstWhere((t) => t.id == widget.tripId).copyWith(
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                    items: _selectedItems,
                    departureDateTime: _departureDateTime,
                    returnDateTime: _returnDateTime,
                    destinationHouseId: _destinationHouseId,
                    updatedAt: now,
                  );
            })()
          : TripModel(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              items: _selectedItems,
              departureDateTime: _departureDateTime,
              returnDateTime: _returnDateTime,
              destinationHouseId: _destinationHouseId,
              createdAt: now,
              updatedAt: now,
            );

      try {
        if (widget.tripId != null) {
          await ref.read(tripNotifierProvider.notifier).updateTrip(trip);
        } else {
          await ref.read(tripNotifierProvider.notifier).addTrip(trip);
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
        context.pop();
      }
    }
  }

  Future<void> _showItemPicker() async {
    final housesAsync = ref.read(houseNotifierProvider);

    final houses = housesAsync.value;
    if (houses == null || houses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna casa disponibile. Aggiungi prima una casa.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => _ItemPickerSheet(
          houses: houses,
          selectedItems: _selectedItems,
          onItemsSelected: (items) {
            setState(() {
              _selectedItems = items;
            });
          },
          onCreateNewItem: () => _createNewItemAndAddToList(),
        ),
      ),
    );
  }

  void _createNewItemAndAddToList() {
    // Apri la schermata di creazione item e aggiungi l'item creato alla lista
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditItemScreen(
          onItemSaved: (itemId, houseId) {
            // Dopo che l'item è stato salvato, recuperalo e aggiungilo alla lista
            _addCreatedItemToList(itemId, houseId);
          },
        ),
      ),
    );
  }

  Future<void> _addCreatedItemToList(String itemId, String houseId) async {
    // Leggi l'item appena creato dal provider
    final itemsAsync = ref.read(itemNotifierProvider(houseId));
    final items = itemsAsync.value;
    if (items == null) return;

    final createdItem = items.where((i) => i.id == itemId).firstOrNull;
    if (createdItem == null) return;

    // Aggiungi l'item alla lista
    setState(() {
      _selectedItems.add(TripItem(
        id: createdItem.id,
        name: createdItem.name,
        category: createdItem.category.displayName,
        quantity: createdItem.quantity ?? 1,
        originHouseId: houseId,
      ));
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${createdItem.name} aggiunto alla lista'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tripId != null ? 'Modifica lista' : 'Nuova lista'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome lista *',
                      border: OutlineInputBorder(),
                      hintText: 'es. Viaggio Roma, Weekend mare...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Il nome è obbligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrizione',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  
                  // Sezione Date
                  Text(
                    'Date del viaggio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Data/ora partenza
                  InkWell(
                    onTap: _pickDepartureDateTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Partenza',
                        border: const OutlineInputBorder(),
                        suffixIcon: _departureDateTime != null 
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _departureDateTime = null),
                              )
                            : const Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDateTime(_departureDateTime)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Data/ora ritorno
                  InkWell(
                    onTap: _pickReturnDateTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ritorno',
                        border: const OutlineInputBorder(),
                        suffixIcon: _returnDateTime != null 
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _returnDateTime = null),
                              )
                            : const Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDateTime(_returnDateTime)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Casa di destinazione
                  Text(
                    'Casa di destinazione (opzionale)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gli oggetti verranno temporaneamente spostati in questa casa durante il viaggio',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 12),
                  housesAsync.when(
                    data: (houses) => _buildDestinationHousePicker(houses),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Errore: $e'),
                  ),
                  const SizedBox(height: 24),
                  
                  // Sezione selezione items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Oggetti (${_selectedItems.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showItemPicker,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Nessun oggetto selezionato',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Premi "Aggiungi" per selezionare oggetti dalle tue case',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_selectedItems.length, (index) {
                      final item = _selectedItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.drag_indicator),
                          title: Text(item.name),
                          subtitle: Text('${item.category} • Quantità: ${item.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeItem(index),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            // Bottone salva
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTrip,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.tripId != null ? 'Salva' : 'Crea lista'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationHousePicker(List houses) {
    if (houses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Nessuna casa disponibile',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final selectedHouse = _destinationHouseId != null
        ? houses.where((h) => h.id == _destinationHouseId).firstOrNull
        : null;

    return InkWell(
      onTap: () => _showDestinationHousePicker(houses),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Casa di arrivo',
          border: const OutlineInputBorder(),
          suffixIcon: _destinationHouseId != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _destinationHouseId = null),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedHouse?.name ?? 'Nessuna (solo spostamento)',
          style: TextStyle(
            color: selectedHouse == null ? Colors.grey : null,
          ),
        ),
      ),
    );
  }

  Future<void> _showDestinationHousePicker(List houses) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Seleziona casa di destinazione',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: const Text('Nessuna (solo spostamento)'),
            trailing: _destinationHouseId == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => Navigator.pop(context, ''),
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
                  subtitle: house.description != null ? Text(house.description) : null,
                  trailing: _destinationHouseId == house.id
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
      setState(() {
        _destinationHouseId = selected.isEmpty ? null : selected;
      });
    }
  }
}

// Sheet per selezionare items dalle case
class _ItemPickerSheet extends ConsumerStatefulWidget {
  final List houses;
  final List<TripItem> selectedItems;
  final Function(List<TripItem>) onItemsSelected;
  final VoidCallback onCreateNewItem;

  const _ItemPickerSheet({
    required this.houses,
    required this.selectedItems,
    required this.onItemsSelected,
    required this.onCreateNewItem,
  });

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  late List<TripItem> _tempSelectedItems;
  String? _expandedHouseId;

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.selectedItems);
  }

  bool _isItemSelected(String itemId) {
    return _tempSelectedItems.any((i) => i.id == itemId);
  }

  void _toggleItem(ItemModel item, String houseId) {
    setState(() {
      if (_isItemSelected(item.id)) {
        _tempSelectedItems.removeWhere((i) => i.id == item.id);
      } else {
        _tempSelectedItems.add(TripItem(
          id: item.id,
          name: item.name,
          category: item.category.displayName,
          quantity: item.quantity ?? 1,
          originHouseId: houseId,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seleziona oggetti',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  widget.onItemsSelected(_tempSelectedItems);
                  Navigator.pop(context);
                },
                child: Text('Fatto (${_tempSelectedItems.length})'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Bottone per creare nuovo oggetto
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              // Salva la selezione corrente e chiudi il picker
              widget.onItemsSelected(_tempSelectedItems);
              Navigator.pop(context);
              // Poi apri la schermata di creazione
              widget.onCreateNewItem();
            },
            icon: const Icon(Icons.add),
            label: const Text('Crea nuovo oggetto'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ),
        const Divider(height: 1),
        // Lista case con items
        Expanded(
          child: ListView.builder(
            itemCount: widget.houses.length,
            itemBuilder: (context, index) {
              final house = widget.houses[index];
              final isExpanded = _expandedHouseId == house.id;

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: Text(
                      house.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onTap: () {
                      setState(() {
                        _expandedHouseId = isExpanded ? null : house.id;
                      });
                    },
                  ),
                  if (isExpanded) _buildHouseItems(house.id),
                  const Divider(height: 1),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHouseItems(String houseId) {
    final itemsAsync = ref.watch(itemNotifierProvider(houseId));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Nessun oggetto in questa casa',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: items.map((item) {
            final isSelected = _isItemSelected(item.id);
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              leading: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleItem(item, houseId),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.category.displayName} • Quantità: ${item.quantity ?? 1}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => _toggleItem(item, houseId),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Errore: $error'),
      ),
    );
  }
}

