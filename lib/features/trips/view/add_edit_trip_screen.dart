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
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/quantity_badge.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../../shared/theme/theme.dart';

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
  String? _destinationLocationName;

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
        _destinationLocationName = trip.destinationLocationName;
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
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      // Imposta automaticamente la data di ritorno a +12 ore
      // se non è già stata impostata o se è prima della partenza
      final autoReturn = _departureDateTime!.add(const Duration(hours: 12));
      if (_returnDateTime == null ||
          _returnDateTime!.isBefore(_departureDateTime!)) {
        _returnDateTime = autoReturn;
      }
    });
  }

  Future<void> _pickReturnDateTime() async {
    final initialDate = _returnDateTime ?? _departureDateTime ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate:
          _departureDateTime ??
          DateTime.now().subtract(const Duration(days: 365)),
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
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
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
            const SnackBar(
              content: Text('La data di ritorno deve essere dopo la partenza'),
            ),
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
              return trips
                  .firstWhere((t) => t.id == widget.tripId)
                  .copyWith(
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                    items: _selectedItems,
                    departureDateTime: _departureDateTime,
                    returnDateTime: _returnDateTime,
                    destinationHouseId: _destinationHouseId,
                    destinationLocationName: _destinationHouseId == null
                        ? _destinationLocationName
                        : null,
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
              destinationLocationName: _destinationHouseId == null
                  ? _destinationLocationName
                  : null,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Errore: $e')));
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
        const SnackBar(
          content: Text('Nessuna casa disponibile. Aggiungi prima una casa.'),
        ),
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
    // Apri il bottom sheet di creazione item e aggiungi l'item creato alla lista
    showAddEditItemSheet(
      context,
      onItemSaved: (itemId, houseId) {
        // Dopo che l'item è stato salvato, recuperalo e aggiungilo alla lista
        _addCreatedItemToList(itemId, houseId);
      },
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
      _selectedItems.add(
        TripItem(
          id: createdItem.id,
          name: createdItem.name,
          category: createdItem.category.displayName,
          quantity: createdItem.quantity ?? 1,
          originHouseId: houseId,
        ),
      );
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
                    decoration: InputDecoration(
                      labelText: 'Nome lista *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.inputBorderRadius,
                        ),
                      ),
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
                    decoration: InputDecoration(
                      labelText: 'Descrizione',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.inputBorderRadius,
                        ),
                      ),
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
                    borderRadius: BorderRadius.circular(
                      AppConstants.inputBorderRadius,
                    ),
                    onTap: _pickDepartureDateTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Partenza',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.inputBorderRadius,
                          ),
                        ),
                        suffixIcon: _departureDateTime != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _departureDateTime = null),
                              )
                            : const Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDateTime(_departureDateTime)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Data/ora ritorno
                  InkWell(
                    borderRadius: BorderRadius.circular(
                      AppConstants.inputBorderRadius,
                    ),
                    onTap: _pickReturnDateTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ritorno',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.inputBorderRadius,
                          ),
                        ),
                        suffixIcon: _returnDateTime != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _returnDateTime = null),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.disabled),
                  ),
                  const SizedBox(height: 12),
                  housesAsync.when(
                    data: (houses) => _buildDestinationHousePicker(houses),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Errore: $e'),
                  ),
                  
                  // Campo di autocomplete località (visibile solo quando nessuna casa è selezionata)
                  if (_destinationHouseId == null) ...[
                    const SizedBox(height: 16),
                    LocationAutocompleteField(
                      initialValue: _destinationLocationName,
                      labelText: 'Destinazione',
                      hintText: 'Cerca città, regione o stato...',
                      onLocationSelected: (location) {
                        setState(() {
                          _destinationLocationName = location.displayName;
                        });
                      },
                      onTextChanged: (text) {
                        setState(() {
                          _destinationLocationName = text.isEmpty ? null : text;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Sezione selezione items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Oggetti (${_selectedItems.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.disabled,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Nessun oggetto selezionato',
                              style: TextStyle(color: AppColors.disabled),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Premi "Aggiungi" per selezionare oggetti dalle tue case',
                              style: TextStyle(
                                color: AppColors.disabled,
                                fontSize: 12,
                              ),
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
                          leading: QuantityBadge(
                            quantity: item.quantity,
                            isSelected: true,
                          ),
                          title: Text(item.name),
                          subtitle: Text(item.category),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.destructive,
                            ),
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
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Nessuna casa disponibile',
          style: TextStyle(color: AppColors.disabled),
        ),
      );
    }

    final selectedHouse = _destinationHouseId != null
        ? houses.where((h) => h.id == _destinationHouseId).firstOrNull
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      onTap: () => _showDestinationHousePicker(houses),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Casa di arrivo',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
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
            color: selectedHouse == null ? AppColors.disabled : null,
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
                ? const Icon(Icons.check, color: AppColors.success)
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
                  subtitle: house.description != null
                      ? Text(house.description)
                      : null,
                  trailing: _destinationHouseId == house.id
                      ? const Icon(Icons.check, color: AppColors.success)
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

  /// Set delle case chiuse (di default tutte sono aperte)
  final Set<String> _collapsedHouseIds = {};

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.selectedItems);
  }

  bool _isItemSelected(String itemId) {
    return _tempSelectedItems.any((i) => i.id == itemId);
  }

  /// Restituisce la quantità selezionata per un item, o 0 se non selezionato
  int _getSelectedQuantity(String itemId) {
    final selected = _tempSelectedItems
        .where((i) => i.id == itemId)
        .firstOrNull;
    return selected?.quantity ?? 0;
  }

  /// Gestisce il tap su un item
  void _handleItemTap(ItemModel item, String houseId) {
    final totalQuantity = item.quantity ?? 1;

    if (totalQuantity == 1) {
      // Quantità 1: toggle semplice
      _toggleItemSimple(item, houseId);
    } else {
      // Quantità > 1: mostra picker quantità
      _showQuantityPicker(item, houseId, totalQuantity);
    }
  }

  /// Toggle semplice per item con quantità 1
  void _toggleItemSimple(ItemModel item, String houseId) {
    setState(() {
      if (_isItemSelected(item.id)) {
        _tempSelectedItems.removeWhere((i) => i.id == item.id);
      } else {
        _tempSelectedItems.add(
          TripItem(
            id: item.id,
            name: item.name,
            category: item.category.displayName,
            quantity: 1,
            originHouseId: houseId,
          ),
        );
      }
    });
  }

  /// Mostra il picker per selezionare la quantità
  Future<void> _showQuantityPicker(
    ItemModel item,
    String houseId,
    int maxQuantity,
  ) async {
    final currentSelected = _getSelectedQuantity(item.id);

    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _QuantityPickerSheet(
        itemName: item.name,
        maxQuantity: maxQuantity,
        currentQuantity: currentSelected,
      ),
    );

    if (result != null) {
      setState(() {
        // Rimuovi l'item esistente se presente
        _tempSelectedItems.removeWhere((i) => i.id == item.id);

        // Aggiungi con la nuova quantità (se > 0)
        if (result > 0) {
          _tempSelectedItems.add(
            TripItem(
              id: item.id,
              name: item.name,
              category: item.category.displayName,
              quantity: result,
              originHouseId: houseId,
            ),
          );
        }
      });
    }
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
              // Di default tutte le case sono aperte (non nel set delle chiuse)
              final isExpanded = !_collapsedHouseIds.contains(house.id);

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
                        if (isExpanded) {
                          _collapsedHouseIds.add(house.id);
                        } else {
                          _collapsedHouseIds.remove(house.id);
                        }
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
              style: TextStyle(color: AppColors.disabled),
            ),
          );
        }

        return Column(
          children: items.map((item) {
            final isSelected = _isItemSelected(item.id);
            final totalQuantity = item.quantity ?? 1;
            final selectedQuantity = _getSelectedQuantity(item.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    AppConstants.cardBorderRadius,
                  ),
                  onTap: () => _handleItemTap(item, houseId),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 48,
                      right: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        // Quantità sempre visibile, stile diverso se selezionato
                        QuantityBadge(
                          quantity: selectedQuantity > 0
                              ? selectedQuantity
                              : totalQuantity,
                          totalQuantity:
                              isSelected && selectedQuantity < totalQuantity
                              ? totalQuantity
                              : null,
                          isSelected: isSelected,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name),
                              Text(
                                item.category.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.disabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

/// Sheet per selezionare la quantità di un item
class _QuantityPickerSheet extends StatefulWidget {
  final String itemName;
  final int maxQuantity;
  final int currentQuantity;

  const _QuantityPickerSheet({
    required this.itemName,
    required this.maxQuantity,
    required this.currentQuantity,
  });

  @override
  State<_QuantityPickerSheet> createState() => _QuantityPickerSheetState();
}

class _QuantityPickerSheetState extends State<_QuantityPickerSheet> {
  late int _selectedQuantity;

  @override
  void initState() {
    super.initState();
    _selectedQuantity = widget.currentQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Quanti "${widget.itemName}" vuoi portare?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Disponibili: ${widget.maxQuantity}',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // Slider o lista di quantità
          if (widget.maxQuantity <= 10)
            // Per quantità piccole, mostra bottoni
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(widget.maxQuantity + 1, (index) {
                final isSelected = _selectedQuantity == index;
                return ChoiceChip(
                  label: Text(index == 0 ? 'Nessuno' : 'x$index'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedQuantity = index);
                  },
                );
              }),
            )
          else
            // Per quantità grandi, usa slider
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _selectedQuantity > 0
                          ? () => setState(() => _selectedQuantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedQuantity == 0
                            ? 'Nessuno'
                            : 'x$_selectedQuantity',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _selectedQuantity < widget.maxQuantity
                          ? () => setState(() => _selectedQuantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _selectedQuantity.toDouble(),
                  min: 0,
                  max: widget.maxQuantity.toDouble(),
                  divisions: widget.maxQuantity,
                  label: _selectedQuantity == 0
                      ? 'Nessuno'
                      : 'x$_selectedQuantity',
                  onChanged: (value) {
                    setState(() => _selectedQuantity = value.round());
                  },
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Bottoni azione
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedQuantity),
                  child: Text(_selectedQuantity == 0 ? 'Rimuovi' : 'Conferma'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
