import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/constants/house_icons.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_error_state.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_field_label.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_icon_picker.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../model/house_model.dart';
import '../providers/house_provider.dart';

/// Mostra il foglio per creare o modificare una casa.
Future<void> showAddEditHouseSheet(BuildContext context, {String? houseId}) {
  return showDsFormSheet(
    context,
    builder: (context) => AddEditHouseSheet(houseId: houseId),
  );
}

/// Foglio della casa, come quello dell'oggetto: tre domande in ordine
/// (dove si trova, come la chiami, che icona) e un solo bottone.
///
/// Il luogo viene prima perché è l'unico obbligatorio e perché dà il nome
/// di riserva: una casa senza nome si chiama come la sua città. In modifica
/// "Salva" si accende solo dopo un cambiamento.
class AddEditHouseSheet extends ConsumerStatefulWidget {
  final String? houseId;

  const AddEditHouseSheet({super.key, this.houseId});

  @override
  ConsumerState<AddEditHouseSheet> createState() => _AddEditHouseSheetState();
}

class _AddEditHouseSheetState extends ConsumerState<AddEditHouseSheet> {
  final _nameController = TextEditingController();
  HouseModel? _existing;
  LocationSuggestionModel? _location;
  String _locationText = '';
  String _iconName = 'home';
  bool _locationMissing = false;
  bool _isSaving = false;

  bool get _isNew => widget.houseId == null;

  bool get _isDirty {
    final existing = _existing;
    if (existing == null) return true;
    return _nameController.text.trim() != existing.name ||
        _location?.placeId != existing.location?.placeId ||
        _location?.displayName != existing.location?.displayName ||
        _iconName != existing.iconName;
  }

  @override
  void initState() {
    super.initState();
    final houses = ref.read(houseNotifierProvider).valueOrNull ?? const [];
    final existing = houses.where((h) => h.id == widget.houseId).firstOrNull;
    if (existing != null) {
      _existing = existing;
      _nameController.text = existing.name;
      _location = existing.location;
      _locationText = existing.location?.displayName ?? '';
      _iconName = existing.iconName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || (!_isNew && _existing == null)) return;
    final location = _location;
    if (location == null) {
      setState(() => _locationMissing = true);
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(houseNotifierProvider.notifier);
    final now = DateTime.now();
    final existing = _existing;
    final name = _nameController.text.trim();
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        if (existing != null) {
          await notifier.updateHouse(
            existing.copyWith(
              name: name,
              location: location,
              iconName: _iconName,
              updatedAt: now,
            ),
          );
        } else {
          final houses = ref.read(houseNotifierProvider).valueOrNull ?? [];
          await notifier.addHouse(
            HouseModel(
              id: const Uuid().v4(),
              name: name,
              location: location,
              iconName: _iconName,
              // La prima casa diventa la principale.
              isPrimary: houses.isEmpty,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      },
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: existing != null
          ? 'errors.save_house_failed'.tr()
          : 'errors.create_house_failed'.tr(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.pop(context);
  }

  Widget _unavailable(Widget child) =>
      DsFormSheet(title: 'houses.edit'.tr(), child: child);

  @override
  Widget build(BuildContext context) {
    if (!_isNew && !_isSaving) {
      final houses = ref.watch(houseNotifierProvider);
      final fallback = houses.when<Widget?>(
        loading: () =>
            _unavailable(const Center(child: CircularProgressIndicator())),
        error: (error, _) => _unavailable(
          DsErrorState(
            error: error,
            title: 'errors.load_houses'.tr(),
            onRetry: () => ref.invalidate(houseNotifierProvider),
          ),
        ),
        data: (houses) {
          final existing = houses
              .where((h) => h.id == widget.houseId)
              .firstOrNull;
          if (existing == null) {
            return _unavailable(
              DsNotFoundState(
                title: 'houses.house_not_found'.tr(),
                icon: Icons.home_outlined,
                actionLabel: 'common.close'.tr(),
                onAction: () => Navigator.pop(context),
              ),
            );
          }
          if (_existing == null) {
            _existing = existing;
            _nameController.text = existing.name;
            _location = existing.location;
            _locationText = existing.location?.displayName ?? '';
            _iconName = existing.iconName;
          }
          return null;
        },
      );
      if (fallback != null) return fallback;
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DsFormSheet(
      title: _isNew ? 'houses.add_new'.tr() : 'houses.edit'.tr(),
      actionLabel: _isNew ? 'common.create'.tr() : 'common.save'.tr(),
      actionKey: const Key('house_sheet_save'),
      onSubmit: _isNew || _isDirty ? _save : null,
      isBusy: _isSaving,
      // La prima etichetta ha già il suo spazio sopra: niente padding in cima.
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsFieldLabel('houses.where_label'.tr()),
          LocationAutocompleteField(
            key: const Key('house_sheet_location'),
            initialValue: _locationText,
            hintText: 'houses.location_hint'.tr(),
            hasError: _locationMissing,
            onLocationSelected: (location) => setState(() {
              _location = location;
              _locationText = location.displayName;
              _locationMissing = false;
            }),
            onTextChanged: (text) {
              _locationText = text;
              // Un luogo scritto a mano non vale: va scelto
              // dalla lista, che porta città e coordinate.
              if (_location != null && text != _location!.displayName) {
                setState(() => _location = null);
              }
            },
          ),
          if (_locationMissing)
            Padding(
              padding: EdgeInsets.only(
                top: context.spacingXs,
                left: context.spacingMd,
              ),
              child: Text(
                'common.select_location'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
          DsFieldLabel('houses.name_label'.tr()),
          DsTextField(
            key: const Key('house_sheet_name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            hintText: 'houses.name_hint'.tr(),
            helperText: 'houses.name_help'.tr(),
            onChanged: (_) => setState(() {}),
          ),
          DsFieldLabel('common.icon'.tr()),
          DsIconPicker(
            icons: HouseIcons.all,
            selectedId: _iconName,
            onSelected: (name) => setState(() => _iconName = name),
          ),
        ],
      ),
    );
  }
}
