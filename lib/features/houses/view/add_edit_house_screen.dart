import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/house_model.dart';
import '../providers/house_provider.dart';
import '../../../shared/constants/app_constants.dart';

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
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

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
        _descriptionController.text = house.description ?? '';
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveHouse() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final now = DateTime.now();
      final house = widget.houseId != null
          ? (() {
              final housesAsync = ref.read(houseNotifierProvider);
              final houses = housesAsync.value;
              if (houses == null) {
                throw StateError('Casa non trovata');
              }
              return houses.firstWhere((h) => h.id == widget.houseId).copyWith(
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                    updatedAt: now,
                  );
            })()
          : HouseModel(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              createdAt: now,
              updatedAt: now,
            );

      try {
        if (widget.houseId != null) {
          await ref.read(houseNotifierProvider.notifier).updateHouse(house);
        } else {
          await ref.read(houseNotifierProvider.notifier).addHouse(house);
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
        Navigator.pop(context);
      }
    }
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
                    autofocus: true,
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
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Descrizione',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.inputBorderRadius),
                      ),
                    ),
                    maxLines: 2,
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
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

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
      _descriptionController.text = house.description ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveHouse() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final now = DateTime.now();
      final house = widget.houseId != null
          ? (() {
              final housesAsync = ref.read(houseNotifierProvider);
              final houses = housesAsync.value;
              if (houses == null) {
                throw StateError('Casa non trovata');
              }
              return houses.firstWhere((h) => h.id == widget.houseId).copyWith(
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                    updatedAt: now,
                  );
            })()
          : HouseModel(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              createdAt: now,
              updatedAt: now,
            );

      try {
        if (widget.houseId != null) {
          await ref.read(houseNotifierProvider.notifier).updateHouse(house);
        } else {
          await ref.read(houseNotifierProvider.notifier).addHouse(house);
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
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descrizione',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
                ),
              ),
              maxLines: 3,
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

