import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'ds_field.dart';
import 'ds_icon_button.dart';

/// Il campo di ricerca: la lente a sinistra, la x per svuotare quando c'è del
/// testo, la rotella al posto della x mentre cerca. Il tasto della tastiera
/// è "cerca".
///
/// Con [inBar] sta dentro la barra in alto di una pagina: niente fondo, bordo
/// né lente. Senza, usa [dsFieldDecoration], quindi la stessa altezza di
/// [DsTextField] e [DsFieldBox].
class DsSearchField extends StatefulWidget {
  const DsSearchField({
    super.key,
    this.controller,
    this.focusNode,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.hasError = false,
    this.errorText,
    this.isLoading = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.inBar = false,
  });

  /// Se manca, il campo ne crea uno suo e lo libera alla chiusura.
  final TextEditingController? controller;

  /// Se manca, il campo ne crea uno suo e lo libera alla chiusura.
  final FocusNode? focusNode;

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Bordo rosso anche senza testo, per esempio una tappa senza luogo.
  final bool hasError;

  /// Errore sotto il campo. Implica [hasError].
  final String? errorText;

  /// Al posto della x mostra la rotella di caricamento.
  final bool isLoading;

  final TextCapitalization textCapitalization;

  /// Dentro la barra in alto: niente fondo, bordo né lente.
  final bool inBar;

  @override
  State<DsSearchField> createState() => _DsSearchFieldState();
}

class _DsSearchFieldState extends State<DsSearchField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? (_ownController = TextEditingController());
    _controller.addListener(_onTextChanged);
    _focusNode = widget.focusNode ?? (_ownFocusNode = FocusNode());
  }

  @override
  void didUpdateWidget(DsSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      _controller =
          widget.controller ?? (_ownController ??= TextEditingController());
      _controller.addListener(_onTextChanged);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode = widget.focusNode ?? (_ownFocusNode ??= FocusNode());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  Widget? _suffix(BuildContext context, ColorScheme cs) {
    if (widget.isLoading) {
      return Padding(
        padding: EdgeInsets.all(context.spacingMd),
        // Del colore della x che sostituisce: è uno stato, non un'azione,
        // quindi niente arancio.
        child: SizedBox.square(
          dimension: context.iconSizeSm,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }
    if (_controller.text.isEmpty) return null;
    return DsIconButton(
      key: const Key('ds_search_clear'),
      tooltip: 'common.clear'.tr(),
      icon: Icons.close,
      color: cs.onSurfaceVariant,
      onPressed: _clear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suffix = _suffix(context, cs);

    final decoration = widget.inBar
        ? InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: suffix,
          )
        : dsFieldDecoration(
            context,
            hasError: widget.hasError || widget.errorText != null,
            hintText: widget.hintText,
            prefixIcon: Icon(
              Icons.search,
              size: context.iconSizeMd,
              color: cs.onSurfaceVariant,
            ),
            suffixIcon: suffix,
          ).copyWith(errorText: widget.errorText);

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: decoration,
      textInputAction: TextInputAction.search,
      textCapitalization: widget.textCapitalization,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
