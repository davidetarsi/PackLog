import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/house_model.dart';
import '../providers/house_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_icon_picker.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/constants/house_icons.dart';

/// Form Content riutilizzabile per house (condiviso tra bottom sheet e full screen)
class HouseFormContent extends ConsumerStatefulWidget {
  final String? houseId;
  final void Function() onSaved;
  final bool showButtons;
  final ValueChanged<bool>? onLoadingChanged;

  const HouseFormContent({
    super.key,
    this.houseId,
    required this.onSaved,
    this.showButtons = true,
    this.onLoadingChanged,
  });

  @override
  ConsumerState<HouseFormContent> createState() => HouseFormContentState();
}

class HouseFormContentState extends ConsumerState<HouseFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  LocationSuggestionModel? _selectedLocation;
  String _locationText = '';
  String _selectedIconName = 'home';

  /// Espone il metodo di salvataggio per uso esterno (es. StandardBottomSheetLayout)
  Future<void> save() => _saveHouse();

  /// Espone lo stato di loading
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    setState(() => _isLoading = value);
    widget.onLoadingChanged?.call(value);
  }

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
      if (_selectedLocation == null) {
        AppSnackBar.showWarning(context, 'common.select_location'.tr());
        return;
      }

      _setLoading(true);

      final now = DateTime.now();
      final housesAsync = ref.read(houseNotifierProvider);
      final existingHouses = housesAsync.value ?? [];

      final willBePrimary = widget.houseId == null && existingHouses.isEmpty;

      final house = widget.houseId != null
          ? (() {
              if (existingHouses.isEmpty) {
                throw StateError('Casa non trovata');
              }
              final existing = existingHouses.firstWhere(
                (h) => h.id == widget.houseId,
              );
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
        errorTitle: 'errors.save_error'.tr(),
        errorMessage: isEditing
            ? 'errors.save_house_failed'.tr()
            : 'errors.create_house_failed'.tr(),
      );

      if (mounted) {
        _setLoading(false);
        if (success) {
          widget.onSaved();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocationAutocompleteField(
            labelText: 'houses.location_label'.tr(),
            initialValue: _locationText,
            hintText: 'houses.location_hint'.tr(),
            showBorder: true,
            onLocationSelected: (location) {
              setState(() {
                _selectedLocation = location;
                _locationText = location.displayName;
              });
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'houses.name_label'.tr(),
              //hintText: 'houses.name_optional_hint'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.inputBorderRadius,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'common.icon'.tr(),
              style: TextStyle(
                fontSize: context.fontSizeSm,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DsIconPicker(
            icons: HouseIcons.all,
            selectedId: _selectedIconName,
            onSelected: (name) => setState(() => _selectedIconName = name),
          ),
          if (widget.showButtons) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveHouse,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.inputBorderRadius,
                  ),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.houseId != null
                          ? 'common.save'.tr()
                          : 'common.create'.tr(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
