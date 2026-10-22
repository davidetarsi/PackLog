import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_field_label.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/widgets/ds_icon_picker.dart';
import '../../items/providers/item_provider.dart';
import '../model/space_model.dart';
import '../providers/space_provider.dart';

Future<SpaceModel?> showAddEditSpaceSheet(
  BuildContext context, {
  required String houseId,
  String? spaceId,
}) => showDsFormSheet<SpaceModel>(
  context,
  builder: (_) => AddEditSpaceSheet(houseId: houseId, spaceId: spaceId),
);

class AddEditSpaceSheet extends ConsumerStatefulWidget {
  const AddEditSpaceSheet({super.key, required this.houseId, this.spaceId});
  final String houseId;
  final String? spaceId;

  @override
  ConsumerState<AddEditSpaceSheet> createState() => _AddEditSpaceSheetState();
}

class _AddEditSpaceSheetState extends ConsumerState<AddEditSpaceSheet> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  SpaceModel? _existing;
  bool _loaded = false;
  bool _busy = false;
  String? _iconName;
  bool get _isNew => widget.spaceId == null;
  bool get _isDirty =>
      _name.text.trim() != _existing?.name || _iconName != _existing?.iconName;
  bool get _canSave =>
      _name.text.trim().isNotEmpty && true && (_isNew || _isDirty);

  void _hydrate(SpaceModel entity) {
    if (_loaded) return;
    _loaded = true;
    _existing = entity;
    _name.text = entity.name;
    _iconName = entity.iconName;
  }

  @override
  void dispose() {
    _name.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_canSave || !_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = _existing;
    final model = existing != null
        ? existing.copyWith(
            name: _name.text.trim(),
            iconName: _iconName,
            updatedAt: now,
          )
        : SpaceModel(
            id: const Uuid().v4(),
            houseId: widget.houseId,
            name: _name.text.trim(),
            iconName: _iconName,
            createdAt: now,
            updatedAt: now,
          );
    setState(() => _busy = true);
    final notifier = ref.read(spaceNotifierProvider(widget.houseId).notifier);
    final saved = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => existing != null
          ? notifier.updateSpace(model)
          : notifier.addSpace(model),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage:
          (existing != null
                  ? 'errors.save_space_failed'
                  : 'errors.create_space_failed')
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
      customTitle: 'spaces.delete'.tr(),
      warningText: 'spaces.delete_warning'.tr(),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final deleted = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(spaceNotifierProvider(widget.houseId).notifier)
          .deleteSpace(entity.id),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.delete_space_failed'.tr(args: [entity.name]),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (deleted) {
      ref.invalidate(itemNotifierProvider(widget.houseId));
      AppSnackBar.showSuccess(
        context,
        'spaces.space_deleted'.tr(args: [entity.name]),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(spaceNotifierProvider(widget.houseId))
      .when(
        loading: () => _sheet(const Center(child: CircularProgressIndicator())),
        error: (error, _) => _sheet(
          DsErrorState(
            error: error,
            message: 'storage.load_failed'.tr(),
            onRetry: () =>
                ref.invalidate(spaceNotifierProvider(widget.houseId)),
          ),
        ),
        data: (entities) {
          if (!_isNew) {
            final entity = entities
                .where((e) => e.id == widget.spaceId)
                .firstOrNull;
            if (entity == null) {
              return _sheet(
                DsEmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'spaces.not_found'.tr(),
                ),
              );
            }
            _hydrate(entity);
          }
          return _sheet(_form(), ready: true);
        },
      );

  Widget _sheet(Widget child, {bool ready = false}) => DsFormSheet(
    title: (_isNew ? 'spaces.add_new' : 'spaces.edit').tr(),
    isBusy: _busy,
    actionLabel: ready ? (_isNew ? 'common.create' : 'common.save').tr() : null,
    actionKey: const Key('space_sheet_save'),
    onSubmit: ready && _canSave ? _save : null,
    actions: [
      if (!_isNew && ready)
        PopupMenuButton<bool>(
          key: const Key('space_sheet_menu'),
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          icon: const Icon(Icons.more_vert),
          onSelected: (_) => _delete(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: true,
              child: Text(
                'spaces.delete'.tr(),
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
        TextFormField(
          key: const Key('space_sheet_name'),
          controller: _name,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: dsFieldDecoration(
            context,
            hintText: 'spaces.name_hint'.tr(),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'common.name_required_validation'.tr()
              : null,
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _save(),
        ),
        DsFieldLabel('common.icon'.tr()),
        DsIconPicker(
          icons: SpaceIcons.all,
          selectedId: _iconName,
          onSelected: (name) => setState(() => _iconName = name),
          onDeselected: (_) => setState(() => _iconName = null),
        ),
      ],
    ),
  );
}
