import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/space_model.dart';
import '../providers/space_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_icon_picker.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';

/// Form Content riutilizzabile per space (condiviso tra bottom sheet e full screen)
class SpaceFormContent extends ConsumerStatefulWidget {
  final String houseId;
  final String? spaceId;
  final void Function()? onSaved;
  final bool showButtons;

  const SpaceFormContent({
    super.key,
    required this.houseId,
    this.spaceId,
    this.onSaved,
    this.showButtons = true,
  });

  @override
  ConsumerState<SpaceFormContent> createState() => SpaceFormContentState();
}

class SpaceFormContentState extends ConsumerState<SpaceFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedIconName;
  bool _isSaving = false;

  /// Chiamato dal parent sheet via GlobalKey. Puro: niente navigazione.
  Future<bool> save() => _saveSpace();

  @override
  void initState() {
    super.initState();
    if (widget.spaceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSpace();
      });
    }
  }

  Future<void> _loadSpace() async {
    final spacesAsync = ref.read(spaceNotifierProvider(widget.houseId));
    spacesAsync.whenData((spaces) {
      final matchingSpaces = spaces.where((s) => s.id == widget.spaceId);
      if (matchingSpaces.isEmpty) return;

      final space = matchingSpaces.first;
      setState(() {
        _nameController.text = space.name;
        _selectedIconName = space.iconName;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<bool> _saveSpace() async {
    if (!_formKey.currentState!.validate()) return false;

    final now = DateTime.now();
    final spaceId = widget.spaceId ?? const Uuid().v4();

    final space = widget.spaceId != null
        ? (() {
            final spacesAsync = ref.read(spaceNotifierProvider(widget.houseId));
            final spaces = spacesAsync.value;
            if (spaces == null) throw StateError('Spazio non trovato');
            return spaces
                .firstWhere((s) => s.id == widget.spaceId)
                .copyWith(
                  name: _nameController.text.trim(),
                  iconName: _selectedIconName,
                  updatedAt: now,
                );
          })()
        : SpaceModel(
            id: spaceId,
            houseId: widget.houseId,
            name: _nameController.text.trim(),
            iconName: _selectedIconName,
            createdAt: now,
            updatedAt: now,
          );

    final isEditing = widget.spaceId != null;
    return ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        if (isEditing) {
          await ref
              .read(spaceNotifierProvider(widget.houseId).notifier)
              .updateSpace(space);
        } else {
          await ref
              .read(spaceNotifierProvider(widget.houseId).notifier)
              .addSpace(space);
        }
      },
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: isEditing
          ? 'errors.save_space_failed'.tr()
          : 'errors.create_space_failed'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            autofocus: widget.spaceId == null,
            decoration: InputDecoration(
              labelText: 'spaces.name_label'.tr(),
              hintText: 'spaces.name_hint'.tr(),
              border: OutlineInputBorder(
                borderRadius: context.responsiveBorderRadius(
                  AppConstants.inputBorderRadius,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'common.name_required_validation'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: context.spacingMd),
          Text(
            'spaces.select_icon'.tr(),
            style: TextStyle(
              fontSize: context.fontSizeSm,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingSm),
          _buildIconSelector(),
          if (widget.showButtons) ...[
            AppSpacing.gapXl,
            UniversalActionBar(
              primaryLabel: widget.spaceId != null
                  ? 'common.save'.tr()
                  : 'common.create'.tr(),
              isLoading: _isSaving,
              onPrimaryPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      final saved = await _saveSpace();
                      if (mounted) {
                        setState(() => _isSaving = false);
                        if (saved) widget.onSaved?.call();
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconSelector() {
    return DsIconPicker(
      icons: SpaceIcons.all,
      selectedId: _selectedIconName,
      onSelected: (name) => setState(() => _selectedIconName = name),
      onDeselected: (_) => setState(() => _selectedIconName = null),
    );
  }
}
