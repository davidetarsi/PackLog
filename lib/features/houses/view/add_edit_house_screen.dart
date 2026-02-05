import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/house_model.dart';
import '../providers/house_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/constants/house_icons.dart';

/// Mostra il bottom sheet per creare o modificare una casa
Future<void> showAddEditHouseSheet(BuildContext context, {String? houseId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditHouseSheet(houseId: houseId),
  );
}

/// Bottom sheet per creare o modificare una casa
class AddEditHouseSheet extends ConsumerStatefulWidget {
  final String? houseId;

  const AddEditHouseSheet({super.key, this.houseId});

  @override
  ConsumerState<AddEditHouseSheet> createState() => _AddEditHouseSheetState();
}

class _AddEditHouseSheetState extends ConsumerState<AddEditHouseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  // Nuovi campi
  LocationSuggestionModel? _selectedLocation;
  String _locationText = '';
  String _selectedIconName = 'home';

  @override
  void initState() {
    super.initState();
    if (widget.houseId != null) {
      _loadHouse();
    }
  }

  Future<void> _loadHouse() async {
    final housesAsync = ref.read(houseNotifierProvider);
    housesAsync.whenData((houses) {
      final house = houses.firstWhere(
        (h) => h.id == widget.houseId,
        orElse: () => throw StateError('Casa non trovata'),
      );
      setState(() {
        _nameController.text = house.name;
        _selectedLocation = house.location;
        _locationText = house.location?.displayName ?? '';
        _selectedIconName = house.iconName;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveHouse() async {
    if (_formKey.currentState!.validate()) {
      // Valida che la località sia stata selezionata
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona una località')),
        );
        return;
      }

      setState(() => _isLoading = true);

      final now = DateTime.now();
      final housesAsync = ref.read(houseNotifierProvider);
      final existingHouses = housesAsync.value ?? [];
      
      // Determina se questa sarà la prima casa (e quindi principale)
      final willBePrimary = widget.houseId == null && existingHouses.isEmpty;

      final house = widget.houseId != null
          ? (() {
              if (existingHouses.isEmpty) {
                throw StateError('Casa non trovata');
              }
              final existing = existingHouses.firstWhere((h) => h.id == widget.houseId);
              return existing.copyWith(
                name: _nameController.text.trim(),
                location: _selectedLocation,
                iconName: _selectedIconName,
                updatedAt: now,
              );
            })()
          : HouseModel(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              location: _selectedLocation,
              iconName: _selectedIconName,
              isPrimary: willBePrimary,
              createdAt: now,
              updatedAt: now,
            );

      final isEditing = widget.houseId != null;
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          if (isEditing) {
            await ref.read(houseNotifierProvider.notifier).updateHouse(house);
          } else {
            await ref.read(houseNotifierProvider.notifier).addHouse(house);
          }
        },
        errorTitle: 'Errore di salvataggio',
        errorMessage: isEditing
            ? 'Impossibile salvare le modifiche alla casa.'
            : 'Impossibile creare la casa.',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }

  /// Mostra il picker per scegliere l'icona
  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scegli un\'icona',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: HouseIcons.all.length,
                  itemBuilder: (context, index) {
                    final iconName = HouseIcons.all.keys.elementAt(index);
                    final iconData = HouseIcons.all[iconName]!;
                    final isSelected = iconName == _selectedIconName;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedIconName = iconName);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              iconData,
                              size: 32,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              HouseIcons.getDisplayName(iconName),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade700,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.houseId != null ? 'Modifica casa' : 'Nuova casa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Form
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    autofocus: widget.houseId == null,
                    decoration: InputDecoration(
                      labelText: 'Nome *',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.inputBorderRadius),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Il nome è obbligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // LocationAutocompleteField
                  LocationAutocompleteField(
                    labelText: 'Località *',
                    hintText: 'Cerca città, regione o stato...',
                    onLocationSelected: (location) {
                      setState(() {
                        _selectedLocation = location;
                        _locationText = location.displayName;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Icon Picker
                  InkWell(
                    onTap: _showIconPicker,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Icona',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.inputBorderRadius),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(HouseIcons.getIcon(_selectedIconName)),
                          const SizedBox(width: 12),
                          Text(HouseIcons.getDisplayName(_selectedIconName)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + AppConstants.bottomSheetBottomPadding,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHouse,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.inputBorderRadius),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.houseId != null ? 'Salva' : 'Crea'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Versione full-screen (mantenuta per retrocompatibilità con le route)
class AddEditHouseScreen extends ConsumerStatefulWidget {
  final String? houseId;

  const AddEditHouseScreen({super.key, this.houseId});

  @override
  ConsumerState<AddEditHouseScreen> createState() => _AddEditHouseScreenState();
}

class _AddEditHouseScreenState extends ConsumerState<AddEditHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  // Nuovi campi
  LocationSuggestionModel? _selectedLocation;
  String _locationText = '';
  String _selectedIconName = 'home';

  @override
  void initState() {
    super.initState();
    if (widget.houseId != null) {
      _loadHouse();
    }
  }

  Future<void> _loadHouse() async {
    final housesAsync = ref.watch(houseNotifierProvider);
    housesAsync.whenData((houses) {
      final house = houses.firstWhere(
        (h) => h.id == widget.houseId,
        orElse: () => throw StateError('Casa non trovata'),
      );
      _nameController.text = house.name;
      setState(() {
        _selectedLocation = house.location;
        _locationText = house.location?.displayName ?? '';
        _selectedIconName = house.iconName;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveHouse() async {
    if (_formKey.currentState!.validate()) {
      // Valida che la località sia stata selezionata
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona una località')),
        );
        return;
      }

      setState(() => _isLoading = true);
      
      final now = DateTime.now();
      final housesAsync = ref.read(houseNotifierProvider);
      final existingHouses = housesAsync.value ?? [];
      
      // Determina se questa sarà la prima casa (e quindi principale)
      final willBePrimary = widget.houseId == null && existingHouses.isEmpty;

      final house = widget.houseId != null
          ? (() {
              if (existingHouses.isEmpty) {
                throw StateError('Casa non trovata');
              }
              final existing = existingHouses.firstWhere((h) => h.id == widget.houseId);
              return existing.copyWith(
                name: _nameController.text.trim(),
                location: _selectedLocation,
                iconName: _selectedIconName,
                updatedAt: now,
              );
            })()
          : HouseModel(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              location: _selectedLocation,
              iconName: _selectedIconName,
              isPrimary: willBePrimary,
              createdAt: now,
              updatedAt: now,
            );

      final isEditing = widget.houseId != null;
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          if (isEditing) {
            await ref.read(houseNotifierProvider.notifier).updateHouse(house);
          } else {
            await ref.read(houseNotifierProvider.notifier).addHouse(house);
          }
        },
        errorTitle: 'Errore di salvataggio',
        errorMessage: isEditing
            ? 'Impossibile salvare le modifiche alla casa.'
            : 'Impossibile creare la casa.',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          context.pop();
        }
      }
    }
  }

  /// Mostra il picker per scegliere l'icona
  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scegli un\'icona',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: HouseIcons.all.length,
                  itemBuilder: (context, index) {
                    final iconName = HouseIcons.all.keys.elementAt(index);
                    final iconData = HouseIcons.all[iconName]!;
                    final isSelected = iconName == _selectedIconName;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedIconName = iconName);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              iconData,
                              size: 32,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              HouseIcons.getDisplayName(iconName),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade700,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.houseId != null ? 'Modifica casa' : 'Nuova casa'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: widget.houseId == null,
              decoration: InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il nome è obbligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // LocationAutocompleteField
            LocationAutocompleteField(
              labelText: 'Località *',
              initialValue: _locationText,
              onLocationSelected: (location) {
                setState(() {
                  _selectedLocation = location;
                  _locationText = location.displayName;
                });
              },
            ),
            const SizedBox(height: 16),
            // Icon Picker
            InkWell(
              onTap: _showIconPicker,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Icona',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.inputBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(HouseIcons.getIcon(_selectedIconName)),
                    const SizedBox(width: 12),
                    Text(HouseIcons.getDisplayName(_selectedIconName)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveHouse,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.houseId != null ? 'Salva' : 'Crea'),
            ),
          ],
        ),
      ),
    );
  }
}
