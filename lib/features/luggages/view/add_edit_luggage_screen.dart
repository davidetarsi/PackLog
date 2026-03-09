import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/luggage_model.dart';
import '../providers/luggage_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/error_retry_dialog.dart';

/// Mostra il bottom sheet per creare o modificare un bagaglio
Future<void> showAddEditLuggageSheet(
  BuildContext context, {
  required String houseId,
  String? luggageId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditLuggageSheet(
      houseId: houseId,
      luggageId: luggageId,
    ),
  );
}

/// Bottom sheet per creare o modificare un bagaglio
class AddEditLuggageSheet extends ConsumerStatefulWidget {
  final String houseId;
  final String? luggageId;

  const AddEditLuggageSheet({
    super.key,
    required this.houseId,
    this.luggageId,
  });

  @override
  ConsumerState<AddEditLuggageSheet> createState() =>
      _AddEditLuggageSheetState();
}

class _AddEditLuggageSheetState extends ConsumerState<AddEditLuggageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _volumeController = TextEditingController();
  LuggageSize _selectedSize = LuggageSize.cabinBaggage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.luggageId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLuggage();
      });
    }
  }

  Future<void> _loadLuggage() async {
    final luggagesAsync = ref.read(luggageNotifierProvider);
    luggagesAsync.whenData((luggages) {
      final matchingLuggages = luggages.where((l) => l.id == widget.luggageId);
      if (matchingLuggages.isEmpty) return;

      final luggage = matchingLuggages.first;
      setState(() {
        _nameController.text = luggage.name;
        _selectedSize = luggage.sizeType;
        if (luggage.volumeLiters != null) {
          _volumeController.text = luggage.volumeLiters.toString();
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _saveLuggage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final luggageId = widget.luggageId ?? const Uuid().v4();
    final volumeLiters = _volumeController.text.trim().isEmpty
        ? null
        : int.tryParse(_volumeController.text.trim());

    final luggage = widget.luggageId != null
        ? (() {
            final luggagesAsync = ref.read(luggageNotifierProvider);
            final luggages = luggagesAsync.value;
            if (luggages == null) throw StateError('Bagaglio non trovato');
            return luggages
                .firstWhere((l) => l.id == widget.luggageId)
                .copyWith(
                  name: _nameController.text.trim(),
                  sizeType: _selectedSize,
                  volumeLiters: volumeLiters,
                  updatedAt: now,
                );
          })()
        : LuggageModel(
            id: luggageId,
            houseId: widget.houseId,
            name: _nameController.text.trim(),
            sizeType: _selectedSize,
            volumeLiters: volumeLiters,
            createdAt: now,
            updatedAt: now,
          );

    final isEditing = widget.luggageId != null;
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        if (isEditing) {
          await ref.read(luggageNotifierProvider.notifier).updateLuggage(luggage);
        } else {
          await ref.read(luggageNotifierProvider.notifier).addLuggage(luggage);
        }
      },
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: isEditing
          ? 'errors.save_luggage_failed'.tr()
          : 'errors.create_luggage_failed'.tr(),
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
                    widget.luggageId != null
                        ? 'luggages.edit'.tr()
                        : 'luggages.add_new'.tr(),
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
                        labelText: 'luggages.name_label'.tr(),
                        hintText: 'luggages.name_hint'.tr(),
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
                    DropdownButtonFormField<LuggageSize>(
                      initialValue: _selectedSize,
                      decoration: InputDecoration(
                        labelText: 'luggages.size_type'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: context.responsiveBorderRadius(
                            AppConstants.inputBorderRadius,
                          ),
                        ),
                      ),
                      items: LuggageSize.values.map((size) {
                        return DropdownMenuItem(
                          value: size,
                          child: Text(size.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedSize = value);
                        }
                      },
                    ),
                    SizedBox(height: context.spacingMd),
                    if (_selectedSize == LuggageSize.custom)
                      TextFormField(
                        controller: _volumeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'luggages.volume_liters'.tr(),
                          hintText: 'luggages.volume_hint'.tr(),
                          suffixText: 'L',
                          border: OutlineInputBorder(
                            borderRadius: context.responsiveBorderRadius(
                              AppConstants.inputBorderRadius,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (_selectedSize == LuggageSize.custom &&
                              (value == null || value.trim().isEmpty)) {
                            return 'luggages.volume_required_for_custom'.tr();
                          }
                          if (value != null && value.trim().isNotEmpty) {
                            final volume = int.tryParse(value.trim());
                            if (volume == null || volume <= 0) {
                              return 'common.invalid_number'.tr();
                            }
                          }
                          return null;
                        },
                      ),
                    if (_selectedSize == LuggageSize.custom)
                      SizedBox(height: context.spacingMd),
                    if (_selectedSize != LuggageSize.custom) ...[
                      Container(
                        padding: EdgeInsets.all(context.spacingSm),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: context.responsiveBorderRadius(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: context.iconSizeSm,
                              color: colorScheme.primary,
                            ),
                            SizedBox(width: context.spacingSm),
                            Expanded(
                              child: Text(
                                'common.approx_volume'.tr(args: [
                                  _selectedSize.approximateVolumeLiters.toString(),
                                ]),
                                style: TextStyle(
                                  fontSize: context.fontSizeSm,
                                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.spacingMd),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveLuggage,
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
                              widget.luggageId != null
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
}
