import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_field_label.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../model/luggage_model.dart';
import '../providers/luggage_provider.dart';

Future<LuggageModel?> showAddEditLuggageSheet(
  BuildContext context, {
  String? luggageId,
}) => showDsFormSheet<LuggageModel>(
  context,
  builder: (_) => AddEditLuggageSheet(luggageId: luggageId),
);

class AddEditLuggageSheet extends ConsumerStatefulWidget {
  const AddEditLuggageSheet({super.key, this.luggageId});
  final String? luggageId;

  @override
  ConsumerState<AddEditLuggageSheet> createState() =>
      _AddEditLuggageSheetState();
}

class _AddEditLuggageSheetState extends ConsumerState<AddEditLuggageSheet> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  LuggageModel? _existing;
  bool _loaded = false;
  bool _busy = false;
  final _volume = TextEditingController();
  LuggageSize _size = LuggageSize.cabinBaggage;
  int? get _liters =>
      _size == LuggageSize.custom ? int.tryParse(_volume.text.trim()) : null;
  bool get _isNew => widget.luggageId == null;
  bool get _isDirty =>
      _name.text.trim() != _existing?.name ||
      _size != _existing?.sizeType ||
      (_size == LuggageSize.custom && _liters != _existing?.volumeLiters);
  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      (_size != LuggageSize.custom || (_liters != null && _liters! > 0)) &&
      (_isNew || _isDirty);

  void _hydrate(LuggageModel entity) {
    if (_loaded) return;
    _loaded = true;
    _existing = entity;
    _name.text = entity.name;
    _size = entity.sizeType;
    _volume.text = entity.volumeLiters?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _volume.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_canSave || !_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = _existing;
    final model = existing != null
        ? existing.copyWith(
            name: _name.text.trim(),
            sizeType: _size,
            volumeLiters: _size == LuggageSize.custom
                ? _liters
                : (_existing?.sizeType == _size
                      ? _existing?.volumeLiters
                      : null),
            updatedAt: now,
          )
        : LuggageModel(
            id: const Uuid().v4(),
            name: _name.text.trim(),
            sizeType: _size,
            volumeLiters: _size == LuggageSize.custom
                ? _liters
                : (_existing?.sizeType == _size
                      ? _existing?.volumeLiters
                      : null),
            createdAt: now,
            updatedAt: now,
          );
    setState(() => _busy = true);
    final notifier = ref.read(luggageNotifierProvider.notifier);
    final saved = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => existing != null
          ? notifier.updateLuggage(model)
          : notifier.addLuggage(model),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage:
          (existing != null
                  ? 'errors.save_luggage_failed'
                  : 'errors.create_luggage_failed')
              .tr(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) Navigator.pop(context, model);
  }

  Future<void> _delete() async {
    final entity = _existing;
    if (_busy || entity == null) return;
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: '',
      itemName: entity.name,
      customTitle: 'luggages.delete'.tr(),
      warningText: 'luggages.delete_warning'.tr(),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final deleted = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(luggageNotifierProvider.notifier).deleteLuggage(entity.id),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.delete_luggage_failed'.tr(args: [entity.name]),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (deleted) {
      AppSnackBar.showSuccess(
        context,
        'luggages.luggage_deleted'.tr(args: [entity.name]),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(luggageNotifierProvider)
      .when(
        loading: () => _sheet(const Center(child: CircularProgressIndicator())),
        error: (error, _) => _sheet(
          DsErrorState(
            error: error,
            title: 'luggages.load_failed'.tr(),
            onRetry: () => ref.invalidate(luggageNotifierProvider),
          ),
        ),
        data: (entities) {
          if (!_isNew) {
            final entity = entities
                .where((e) => e.id == widget.luggageId)
                .firstOrNull;
            if (entity == null) {
              return _sheet(
                DsNotFoundState(
                  icon: Icons.luggage_outlined,
                  title: 'luggages.not_found'.tr(),
                  actionLabel: 'common.close'.tr(),
                  onAction: () => Navigator.pop(context),
                ),
              );
            }
            _hydrate(entity);
          }
          return _sheet(_form(), ready: true);
        },
      );

  Widget _sheet(Widget child, {bool ready = false}) => DsFormSheet(
    title: (_isNew ? 'luggages.add_new' : 'luggages.edit').tr(),
    isBusy: _busy,
    actionLabel: ready ? (_isNew ? 'common.create' : 'common.save').tr() : null,
    actionKey: const Key('luggage_sheet_save'),
    onSubmit: ready && _canSave ? _save : null,
    actions: [
      if (!_isNew && ready)
        PopupMenuButton<bool>(
          key: const Key('luggage_sheet_menu'),
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          icon: const Icon(Icons.more_vert),
          onSelected: (_) => _delete(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: true,
              child: Text(
                'luggages.delete'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
    ],
    child: child,
  );

  Widget _form() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsFieldLabel('items.name_label'.tr()),
        DsTextField(
          key: const Key('luggage_sheet_name'),
          controller: _name,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          hintText: 'luggages.name_hint'.tr(),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'common.name_required_validation'.tr()
              : null,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        DsFieldLabel('luggages.size_label'.tr()),
        DsFieldBox(
          key: const Key('luggage_sheet_size'),
          icon: Icons.luggage_outlined,
          suffixIcon: const Icon(Icons.expand_more),
          onTap: () async {
            final picked = await DsPickerSheet.show<LuggageSize>(
              context: context,
              title: 'luggages.size_label'.tr(),
              items: LuggageSize.values,
              getLabel: (s) => s.displayName,
              selected: _size,
            );
            if (picked != null && mounted) setState(() => _size = picked);
          },
          child: Text(_size.displayName),
        ),
        if (_size == LuggageSize.custom) ...[
          DsFieldLabel('luggages.volume_label'.tr()),
          DsTextField(
            key: const Key('luggage_sheet_volume'),
            controller: _volume,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            hintText: 'luggages.volume_hint'.tr(),
            suffixText: 'L',
            validator: (value) =>
                int.tryParse(value?.trim() ?? '') == null ||
                    int.parse(value!.trim()) <= 0
                ? 'common.invalid_number'.tr()
                : null,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
        ] else
          Padding(
            padding: EdgeInsets.only(top: context.spacingSm),
            child: Text(
              'common.approx_volume'.tr(
                args: ['${_size.approximateVolumeLiters}'],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ),
  );
}
