import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../services/category_infer_service.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import 'category_pill.dart';

class RapidFireInput extends ConsumerStatefulWidget {
  final String houseId;
  final String? currentSpaceId;
  final void Function(String name, ItemCategory category)? onOpenFullForm;
  final ValueChanged<bool>? onExpandedChanged;
  final double height;

  const RapidFireInput({
    super.key,
    required this.houseId,
    this.currentSpaceId,
    this.onOpenFullForm,
    this.onExpandedChanged,
    this.height = 50.0,
  });

  @override
  ConsumerState<RapidFireInput> createState() => _RapidFireInputState();
}

class _RapidFireInputState extends ConsumerState<RapidFireInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isExpanded = false;
  ItemCategory? _forcedCategory;
  ({ItemCategory category, InferConfidence confidence})? _inferResult;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final expanded = _focusNode.hasFocus;
    if (expanded != _isExpanded) {
      setState(() => _isExpanded = expanded);
      widget.onExpandedChanged?.call(expanded);
    }
  }

  void _handleTextChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _inferResult = null);
      return;
    }
    if (_forcedCategory == null) {
      final service = ref.read(categoryInferServiceProvider).valueOrNull;
      if (service == null) return;
      final result = service.infer(trimmed);
      setState(() => _inferResult = result);
    }
  }

  void _toggleForcedCategory(ItemCategory category) {
    setState(() {
      if (_forcedCategory == category) {
        _forcedCategory = null;
        if (_textController.text.trim().isNotEmpty) {
          final service = ref.read(categoryInferServiceProvider).valueOrNull;
        if (service != null) {
          _inferResult = service.infer(_textController.text.trim());
        }
        }
      } else {
        _forcedCategory = category;
      }
    });
  }

  CategoryPillState _computePillState(ItemCategory category) {
    if (_forcedCategory == category) return CategoryPillState.forced;
    if (_forcedCategory != null) return CategoryPillState.inactive;
    if (_inferResult?.category == category) return CategoryPillState.inferred;
    return CategoryPillState.inactive;
  }

  Future<void> _handleSubmit() async {
    final name = _textController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final category =
        _forcedCategory ?? _inferResult?.category ?? ItemCategory.varie;

    final item = ItemModel(
      id: const Uuid().v4(),
      houseId: widget.houseId,
      name: name,
      category: category,
      quantity: 1,
      spaceId: widget.currentSpaceId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .addItem(item);

      _textController.clear();
      _forcedCategory = null;
      _inferResult = null;
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'errors.create_item_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _textController.text.trim().isNotEmpty;

    // 1. Intercettiamo tasto Indietro (Android) e i tocchi fuori dal widget
    return PopScope(
      canPop: !_isExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isExpanded) {
          _focusNode.unfocus();
        }
      },
      child: TapRegion(
        onTapOutside: (event) {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
        // 2. Colonna principale che "splitta" le categorie dall'input
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // FORZA i figli a prendere tutta la larghezza disponibile!
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            // --- BLOCCO 1: ROW DELLE CATEGORIE (Separate e fluttuanti) ---
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: _isExpanded
                  ? AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isExpanded ? 1.0 : 0.0,
                      child: Padding(
                        // Spazio visivo tra le categorie fluttuanti e l'input sottostante
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final category in ItemCategory.values) ...[
                              if (category != ItemCategory.values.first)
                                SizedBox(width: context.responsive(6)),
                              CategoryPill(
                                category: category,
                                pillState: _computePillState(category),
                                onTap: () => _toggleForcedCategory(category),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // --- BLOCCO 2: CONTAINER DELL'INPUT TEXT (Pillola indipendente) ---
            GestureDetector(
              onTap: () {
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: widget.height,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  // Il bordo dinamico come richiesto
                  border: Border.all(
                    color: Colors.transparent,
                    width: 1.5,
                  ),
                  // Mantiene perennemente la forma a pillola (metà altezza)
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
                clipBehavior: Clip.antiAlias,
                // Gestione fluida del padding orizzontale
                padding: EdgeInsets.only(
                  left: _isExpanded ? context.spacingSm : context.spacingMd,
                  right: 6.0, 
                ),
                child: Row(
                  children: [
                    // Pulsante "+" visibile solo in stato espanso
                    if (_isExpanded) ...[
                      IconButton(
                        icon: Icon(Icons.add, size: context.responsive(24)),
                        onPressed: () {
                          final name = _textController.text.trim();
                          final category = _forcedCategory ??
                              _inferResult?.category ??
                              ItemCategory.varie;
                          widget.onOpenFullForm?.call(name, category);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // TextField espanso al massimo (ora il testo andrà fino in fondo)
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        focusNode: _focusNode,
                        autofocus: false,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'items.rapid_fire_hint'.tr(),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          // Nessun padding aggiuntivo, lo gestisce il Container padre
                          contentPadding: EdgeInsets.zero, 
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleSubmit(),
                        onChanged: _handleTextChanged,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),


                    // Bottone Invia
                    _SubmitButton(
                      enabled: hasText && !_isSubmitting,
                      onPressed: _handleSubmit,
                      isSubmitting: _isSubmitting,
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

class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final bool isSubmitting;

  const _SubmitButton({
    required this.enabled,
    required this.onPressed,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = enabled
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final iconColor = enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: isSubmitting
            ? Padding(
                padding: const EdgeInsets.all(6),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(Icons.arrow_upward, size: 18, color: iconColor),
      ),
    );
  }
}
