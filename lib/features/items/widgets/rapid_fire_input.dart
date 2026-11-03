import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../helpers/copies_parser.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../services/category_infer_service.dart';
import '../../../shared/helpers/first_letter_formatter.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_opacity.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_motion.dart';
import 'category_pill.dart';

/// Gruppo dei tocchi "dentro" il rapid fire. Chi mostra contenuti legati al
/// campo (la pagina "aggiungi" della casa) li avvolge in un [TapRegion] con
/// questo gruppo: toccarli non chiude il campo.
const Object rapidFireTapRegionGroup = _RapidFireTapRegionGroup();

class _RapidFireTapRegionGroup {
  const _RapidFireTapRegionGroup();
}

/// Chiave di SharedPreferences: la riga che spiega le copie si mostra una
/// volta sola.
const String rapidFireCopiesTipSeenKey = 'rapid_fire_copies_tip_seen';

class RapidFireInput extends ConsumerStatefulWidget {
  final String houseId;
  final String? currentSpaceId;
  final ValueChanged<bool>? onExpandedChanged;
  final double height;

  /// Ogni modifica del testo (anche lo svuotamento dopo il salvataggio).
  final ValueChanged<String>? onTextChanged;

  /// Focus del campo, se lo gestisce il chiamante (la casa lo usa per aprire
  /// la pagina "aggiungi" dallo stato vuoto). Se nullo il campo ne crea uno.
  final FocusNode? focusNode;

  /// Prende il focus appena montato (tastiera su, modalità espansa).
  final bool autofocus;

  /// Chiamato con l'oggetto creato, dopo un salvataggio riuscito.
  final ValueChanged<ItemModel>? onItemCreated;

  /// Segnaposto del campo, al posto di `items.rapid_fire_hint`.
  final String? hintText;

  /// Falso: il campo non si scrive e non invia (stile disabilitato del tema).
  final bool enabled;

  const RapidFireInput({
    super.key,
    required this.houseId,
    this.autofocus = false,
    this.currentSpaceId,
    this.onExpandedChanged,
    this.onTextChanged,
    this.focusNode,
    this.onItemCreated,
    this.hintText,
    this.enabled = true,
    this.height = 50.0,
  });

  @override
  ConsumerState<RapidFireInput> createState() => _RapidFireInputState();
}

class _RapidFireInputState extends ConsumerState<RapidFireInput> {
  final _textController = TextEditingController();
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  bool _isExpanded = false;
  ItemCategory? _forcedCategory;
  ({ItemCategory category, InferConfidence confidence})? _inferResult;
  bool _isSubmitting = false;

  /// Vero dopo che si è toccata la pillola ×N: per questo testo le copie non
  /// contano. Torna falso quando il campo si svuota.
  bool _copiesDismissed = false;
  bool _tipVisible = false;
  Future<bool>? _tipSeen;

  /// Le copie lette dal testo, se la pillola è attiva.
  ({String name, int copies})? get _copies =>
      _copiesDismissed ? null : parseCopies(_textController.text);

  @override
  void initState() {
    super.initState();
    _tipSeen = _loadTipSeen();
    _focusNode.addListener(_onFocusChanged);
    if (widget.autofocus) {
      // Dopo il primo frame: durante la transizione di route il focus
      // richiesto subito andrebbe perso.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final expanded = _focusNode.hasFocus;
    if (expanded != _isExpanded) {
      setState(() => _isExpanded = expanded);
      widget.onExpandedChanged?.call(expanded);
    }
  }

  Future<bool> _loadTipSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(rapidFireCopiesTipSeenKey) ?? false;
    } catch (_) {
      // Senza preferenze meglio non mostrare la riga che ripeterla sempre.
      return true;
    }
  }

  /// La prima volta che la pillola compare mostra la riga che la spiega e
  /// ricorda di averlo fatto.
  Future<void> _maybeShowTip() async {
    final seenFuture = _tipSeen;
    if (seenFuture == null) return;
    // Una sola decisione per sessione: dopo questa la riga è "vista".
    _tipSeen = Future.value(true);
    final seen = await seenFuture;
    if (seen || !mounted) return;
    setState(() => _tipVisible = _copies != null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(rapidFireCopiesTipSeenKey, true);
    } catch (_) {}
  }

  /// Il menu del testo (Incolla, Copia...) vive in un overlay fuori dal campo:
  /// nel gruppo del rapid fire, altrimenti toccarlo conta come tocco fuori e
  /// toglie il focus prima che l'azione parta.
  Widget _buildContextMenu(BuildContext context, EditableTextState state) {
    return TapRegion(
      groupId: rapidFireTapRegionGroup,
      child: AdaptiveTextSelectionToolbar.editableText(
        editableTextState: state,
      ),
    );
  }

  /// Il nome su cui ragiona la categoria: senza il numero delle copie, se la
  /// pillola è attiva.
  String _nameForInference(String value) => (_copies?.name ?? value).trim();

  void _handleTextChanged(String value) {
    widget.onTextChanged?.call(value);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _inferResult = null;
        _copiesDismissed = false;
        _tipVisible = false;
      });
      return;
    }
    final hasPill = _copies != null;
    if (hasPill) {
      _maybeShowTip();
    }
    if (_forcedCategory == null) {
      final service = ref.read(categoryInferServiceProvider).valueOrNull;
      if (service == null) {
        setState(() => _tipVisible = _tipVisible && hasPill);
        return;
      }
      final result = service.infer(_nameForInference(value));
      setState(() {
        _inferResult = result;
        _tipVisible = _tipVisible && hasPill;
      });
    } else {
      setState(() => _tipVisible = _tipVisible && hasPill);
    }
  }

  void _dismissCopies() {
    setState(() {
      _copiesDismissed = true;
      _tipVisible = false;
      if (_forcedCategory == null) {
        final service = ref.read(categoryInferServiceProvider).valueOrNull;
        final text = _textController.text.trim();
        if (service != null && text.isNotEmpty) {
          _inferResult = service.infer(text);
        }
      }
    });
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
    final text = _textController.text.trim();
    if (!widget.enabled || text.isEmpty || _isSubmitting) return;

    final copies = _copies;
    final String name;
    final int quantity;
    if (copies != null) {
      name = _capitalizeAfterCount(text, copies.name);
      quantity = copies.copies;
    } else {
      name = text;
      quantity = 1;
    }

    setState(() => _isSubmitting = true);

    final category =
        _forcedCategory ?? _inferResult?.category ?? ItemCategory.varie;

    final item = ItemModel(
      id: const Uuid().v4(),
      houseId: widget.houseId,
      name: name,
      category: category,
      quantity: quantity,
      spaceId: widget.currentSpaceId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .addItem(item, categoryChosen: _forcedCategory != null);

      // Il campo è sparito mentre si salvava (un foglio chiuso a metà): se
      // ne perde solo l'aspetto, l'oggetto esiste e chi ascolta lo deve sapere.
      if (!mounted) {
        widget.onItemCreated?.call(item);
        return;
      }
      _textController.clear();
      widget.onTextChanged?.call('');
      _forcedCategory = null;
      _inferResult = null;
      _copiesDismissed = false;
      _tipVisible = false;
      HapticFeedback.lightImpact();
      widget.onItemCreated?.call(item);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'errors.create_item_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Con il numero davanti ("2 t-shirt nere") il formatter ha già guardato la
  /// cifra e non la lettera: il nome rimasto prende la maiuscola qui. Se il
  /// numero è in fondo il formatter ha già fatto il suo.
  String _capitalizeAfterCount(String original, String stripped) {
    if (!RegExp(r'^\d').hasMatch(original) || stripped.isEmpty) return stripped;
    final first = stripped.substring(0, 1);
    final upper = first.toUpperCase();
    if (upper == first || upper.length != first.length) return stripped;
    return upper + stripped.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _textController.text.trim().isNotEmpty;
    final copies = _copies;

    // 1. Intercettiamo tasto Indietro (Android) e i tocchi fuori dal widget
    return PopScope(
      canPop: !_isExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isExpanded) {
          _focusNode.unfocus();
        }
      },
      child: TapRegion(
        groupId: rapidFireTapRegionGroup,
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
            // Nessuna animazione legata al focus: la barra sale con la
            // tastiera, frame per frame, e le pillole ci sono o non ci sono.
            // Il wrapper stabile evita che il cambio focus + tip copie ricrei
            // il TextField durante l'invio.
            Padding(
              padding: EdgeInsets.only(
                bottom: _isExpanded ? context.spacingSm : 0,
              ),
              child: _isExpanded
                  ? SizedBox(
                      height: widget.height,
                      child: Row(
                        children: [
                          for (final category in ItemCategory.values) ...[
                            if (category != ItemCategory.values.first)
                              SizedBox(width: context.spacingXs),
                            Expanded(
                              child: CategoryPill(
                                category: category,
                                pillState: _computePillState(category),
                                onTap: () => _toggleForcedCategory(category),
                              ),
                            ),
                          ],
                        ],
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
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                height: widget.height,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  // Bordo neutro: nella casa l'arancio è del bottone AI, la
                  // strada che vogliamo far prendere. Il campo resta
                  // riconoscibile per la forma e il segnaposto.
                  border: Border.all(color: colorScheme.outlineVariant),
                  // Mantiene perennemente la forma a pillola (metà altezza)
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
                clipBehavior: Clip.antiAlias,
                // Gestione fluida del padding orizzontale
                padding: EdgeInsets.only(
                  left: context.spacingMd,
                  right: context.spacingXs,
                ),
                child: Row(
                  children: [
                    // TextField espanso al massimo (ora il testo andrà fino in fondo)
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        enabled: widget.enabled,
                        textCapitalization: TextCapitalization.sentences,
                        // Il campo resta a fuoco dopo ogni invio e la tastiera
                        // non rimette la maiuscola: la mette il formatter.
                        inputFormatters: const [FirstLetterFormatter()],
                        contextMenuBuilder: _buildContextMenu,
                        focusNode: _focusNode,
                        autofocus: false,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText:
                              widget.hintText ?? 'items.rapid_fire_hint'.tr(),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          // Nessun padding aggiuntivo, lo gestisce il Container padre
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                        // Il campo resta attivo dopo l'invio: il rapid fire
                        // serve a scrivere più oggetti di fila (vedi "Aggiunti
                        // ora" nella pagina aggiungi). Si chiude con indietro o
                        // toccando fuori.
                        onEditingComplete: () {},
                        onSubmitted: (_) => _handleSubmit(),
                        onChanged: _handleTextChanged,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),

                    // Pillola delle copie: tocca per toglierla.
                    if (copies != null)
                      Padding(
                        padding: EdgeInsets.only(right: context.spacingXs),
                        child: _CopiesPill(
                          copies: copies.copies,
                          onTap: _dismissCopies,
                        ),
                      ),

                    // Bottone Invia
                    _SubmitButton(
                      enabled: widget.enabled && hasText && !_isSubmitting,
                      onPressed: _handleSubmit,
                      isSubmitting: _isSubmitting,
                    ),
                  ],
                ),
              ),
            ),

            // --- BLOCCO 3: la riga che spiega le copie (solo la prima volta) ---
            if (_tipVisible && copies != null)
              Padding(
                padding: EdgeInsets.only(
                  top: context.spacingXs,
                  left: context.spacingMd,
                  right: context.spacingMd,
                ),
                child: Text(
                  'items.copies_tip'.tr(args: ['${copies.copies}']),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "×N" accanto al bottone invia: fondo tenue dell'arancio, mai pieno (l'arancio
/// pieno è del bottone).
class _CopiesPill extends StatelessWidget {
  final int copies;
  final VoidCallback onTap;

  const _CopiesPill({required this.copies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: BoxConstraints(minHeight: context.iconSizeLg),
          padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: AppOpacity.selected),
            borderRadius: BorderRadius.circular(context.iconSizeLg / 2),
          ),
          child: Text(
            '×$copies',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
          ),
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
        duration: AppMotion.fast,
        width: context.iconSizeLg,
        height: context.iconSizeLg,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: isSubmitting
            ? Padding(
                padding: EdgeInsets.all(context.spacingXs),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(
                Icons.arrow_upward,
                size: context.iconSizeSm,
                color: iconColor,
              ),
      ),
    );
  }
}
