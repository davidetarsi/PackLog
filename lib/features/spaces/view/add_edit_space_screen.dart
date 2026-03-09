import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/space_model.dart';
import '../providers/space_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/error_retry_dialog.dart';

/// Mostra il bottom sheet per creare o modificare uno spazio
Future<void> showAddEditSpaceSheet(
  BuildContext context, {
  required String houseId,
  String? spaceId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditSpaceSheet(
      houseId: houseId,
      spaceId: spaceId,
    ),
  );
}

/// Bottom sheet per creare o modificare uno spazio
class AddEditSpaceSheet extends ConsumerStatefulWidget {
  final String houseId;
  final String? spaceId;

  const AddEditSpaceSheet({
    super.key,
    required this.houseId,
    this.spaceId,
  });

  @override
  ConsumerState<AddEditSpaceSheet> createState() => _AddEditSpaceSheetState();
}

class _AddEditSpaceSheetState extends ConsumerState<AddEditSpaceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedIconName;
  bool _isLoading = false;

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
    final spacesAsync = ref.read(spaceNotifierProvider);
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

  Future<void> _saveSpace() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final spaceId = widget.spaceId ?? const Uuid().v4();

    final space = widget.spaceId != null
        ? (() {
            final spacesAsync = ref.read(spaceNotifierProvider);
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
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        if (isEditing) {
          await ref.read(spaceNotifierProvider.notifier).updateSpace(space);
        } else {
          await ref.read(spaceNotifierProvider.notifier).addSpace(space);
        }
      },
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: isEditing
          ? 'errors.save_space_failed'.tr()
          : 'errors.create_space_failed'.tr(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.responsive(20)),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: context.responsiveScreenPadding,
              child: Row(
                children: [
                  Text(
                    widget.spaceId != null
                        ? 'spaces.edit'.tr()
                        : 'spaces.add_new'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: context.iconSizeMd),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacingMd,
                0,
                context.spacingMd,
                context.spacingMd + AppConstants.bottomSheetBottomPadding,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
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
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: context.spacingSm),
                    _buildIconSelector(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveSpace,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: context.spacingMd),
                        shape: RoundedRectangleBorder(
                          borderRadius: context.responsiveBorderRadius(
                            AppConstants.inputBorderRadius,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: context.responsive(20),
                              width: context.responsive(20),
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.spaceId != null
                                  ? 'common.save'.tr()
                                  : 'common.create'.tr(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final icons = {
      'meeting_room': Icons.meeting_room,
      'kitchen': Icons.kitchen,
      'bed': Icons.bed,
      'living': Icons.living,
      'bathroom': Icons.bathroom,
      'door_sliding': Icons.door_sliding,
      'garage': Icons.garage,
      'yard': Icons.yard,
      'balcony': Icons.balcony,
      'storage': Icons.storage,
      'workspaces': Icons.workspaces,
      'dining': Icons.restaurant,
      'desk': Icons.desk,
      'chair': Icons.chair,
      'shelves': Icons.shelves,
    };

    return Wrap(
      spacing: context.spacingSm,
      runSpacing: context.spacingSm,
      children: icons.entries.map((entry) {
        final iconName = entry.key;
        final iconData = entry.value;
        final isSelected = _selectedIconName == iconName;

        return InkWell(
          borderRadius: context.responsiveBorderRadius(8),
          onTap: () {
            setState(() {
              _selectedIconName = isSelected ? null : iconName;
            });
          },
          child: Container(
            padding: EdgeInsets.all(context.spacingSm),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surface,
              borderRadius: context.responsiveBorderRadius(8),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              iconData,
              size: context.iconSizeMd,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }
}
