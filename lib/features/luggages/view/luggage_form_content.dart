import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/luggage_model.dart';
import '../providers/luggage_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';

/// Form Content riutilizzabile per luggage (condiviso tra bottom sheet e full screen)
class LuggageFormContent extends ConsumerStatefulWidget {
  final String houseId;
  final String? luggageId;
  final void Function() onSaved;
  final bool showButtons;
  final ValueChanged<bool>? onLoadingChanged;

  const LuggageFormContent({
    super.key,
    required this.houseId,
    this.luggageId,
    required this.onSaved,
    this.showButtons = true,
    this.onLoadingChanged,
  });

  @override
  ConsumerState<LuggageFormContent> createState() => LuggageFormContentState();
}

class LuggageFormContentState extends ConsumerState<LuggageFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _volumeController = TextEditingController();
  LuggageSize _selectedSize = LuggageSize.cabinBaggage;
  bool _isLoading = false;

  /// Espone il metodo di salvataggio per uso esterno
  Future<void> save() => _saveLuggage();

  /// Espone lo stato di loading
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    setState(() => _isLoading = value);
    widget.onLoadingChanged?.call(value);
  }

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

    _setLoading(true);

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
      _setLoading(false);
      if (success) {
        widget.onSaved();
      }
    }
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
            autofocus: widget.luggageId == null,
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
          if (widget.showButtons) ...[
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
        ],
      ),
    );
  }
}
