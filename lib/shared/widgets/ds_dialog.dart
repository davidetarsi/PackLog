import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'ds_button.dart';
import 'ds_text_button.dart';

/// Apre un dialogo del design system. È l'unico punto del codice che chiama
/// `showDialog`: ogni dialogo passa da qui e da [DsDialog].
Future<T?> showDsDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
  );
}

/// Cornice di tutti i dialoghi: titolo, messaggio (o contenuto libero) e
/// azioni. Forma, colori e spaziature sono qui e non nel chiamante.
///
/// - Con [icon] il dialogo è centrato, come quello di errore.
/// - Con una sola azione, questa occupa tutta la larghezza.
/// - Con due azioni, usa [DsDialog.twoActions]: due pill di pari larghezza.
class DsDialog extends StatelessWidget {
  final String title;

  /// Icona grande sopra il titolo (per gli errori).
  final IconData? icon;

  /// Colore dell'icona. Se manca, è `onSurfaceVariant`.
  final Color? iconColor;

  /// Testo semplice sotto il titolo.
  final String? message;

  /// Contenuto libero, al posto di [message].
  final Widget? content;

  /// Azioni in fondo: una sola, oppure [DsDialog.twoActions].
  final List<Widget> actions;

  const DsDialog({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.message,
    this.content,
    this.actions = const [],
  });

  /// Due azioni affiancate. Le conferme normali usano due pill; quelle
  /// distruttive danno rilievo ad Annulla e lasciano la conferma in rosso.
  ///
  /// La prima scelta chiude il dialogo: i tocchi successivi, dati prima che
  /// l'uscita finisca, vengono ignorati. Altrimenti il secondo tocco
  /// chiuderebbe anche la pagina sotto.
  static Widget twoActions({
    required String cancelLabel,
    required VoidCallback onCancel,
    required String confirmLabel,
    required VoidCallback? onConfirm,
    bool isDestructive = false,
    bool confirmAsText = false,
  }) {
    return _TwoActions(
      cancelLabel: cancelLabel,
      onCancel: onCancel,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
      isDestructive: isDestructive,
      confirmAsText: confirmAsText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final centered = icon != null;

    final Widget? body =
        content ??
        (message == null
            ? null
            : Text(
                message!,
                textAlign: centered ? TextAlign.center : null,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ));

    // Una sola azione occupa tutta la riga (Expanded la stringe anche se è un
    // bottone di solo testo); più azioni si dividono la riga in parti uguali.
    final Widget? actionArea = actions.isEmpty
        ? null
        : Row(
            children: [
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) SizedBox(width: context.spacingSm),
                Expanded(child: action),
              ],
            ],
          );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.modalBorderRadius),
      ),
      icon: icon == null
          ? null
          : Icon(
              icon,
              size: context.iconSizeXl,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
      title: Text(
        title,
        textAlign: centered ? TextAlign.center : null,
        style: theme.textTheme.titleLarge?.title,
      ),
      content: body,
      // A scala grande titolo e testo possono superare l'altezza dello
      // schermo: il dialogo scorre invece di andare in overflow.
      scrollable: true,
      contentPadding: EdgeInsets.all(context.spacingLg),
      actionsPadding: EdgeInsets.fromLTRB(
        context.spacingLg,
        context.spacingSm,
        context.spacingLg,
        context.spacingLg,
      ),
      actions: actionArea == null ? null : [actionArea],
    );
  }
}

/// Le due azioni di [DsDialog.twoActions]. Tiene un flag: la prima scelta
/// vince, le altre no.
class _TwoActions extends StatefulWidget {
  final String cancelLabel;
  final VoidCallback onCancel;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool isDestructive;
  final bool confirmAsText;

  const _TwoActions({
    required this.cancelLabel,
    required this.onCancel,
    required this.confirmLabel,
    required this.onConfirm,
    required this.isDestructive,
    required this.confirmAsText,
  });

  @override
  State<_TwoActions> createState() => _TwoActionsState();
}

class _TwoActionsState extends State<_TwoActions> {
  bool _chosen = false;

  void _choose(VoidCallback action) {
    if (_chosen) return;
    _chosen = true;
    action();
  }

  @override
  Widget build(BuildContext context) {
    final onConfirm = widget.onConfirm;
    if (widget.isDestructive || widget.confirmAsText) {
      final theme = Theme.of(context);
      final textScaler = MediaQuery.textScalerOf(context);
      final cancelWidth = _singleLineTextWidth(
        widget.cancelLabel,
        theme.textTheme.bodyMedium?.strong,
        textScaler,
        Directionality.of(context),
      );
      final confirmWidth = _singleLineTextWidth(
        widget.confirmLabel,
        theme.textTheme.labelLarge?.strong,
        textScaler,
        Directionality.of(context),
      );
      // AlertDialog ha inset orizzontale di 40 dp e larghezza massima 560 dp;
      // sottraiamo anche il padding laterale usato per le azioni.
      final viewportWidth = MediaQuery.sizeOf(context).width;
      final dialogWidth = viewportWidth > 600 ? 560.0 : viewportWidth - 80;
      final actionWidth = dialogWidth - context.spacingLg * 2;
      final availableLabelWidth =
          (actionWidth - context.spacingSm) / 2 - context.spacingMd * 2;
      final shouldStack =
          cancelWidth > availableLabelWidth ||
          confirmWidth > availableLabelWidth;

      if (shouldStack) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsButton(
              label: widget.cancelLabel,
              variant: DsButtonVariant.primary,
              expand: true,
              wrapLabel: true,
              onPressed: () => _choose(widget.onCancel),
            ),
            SizedBox(height: context.spacingXs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DsTextButton(
                label: widget.confirmLabel,
                destructive: widget.isDestructive,
                onPressed: onConfirm == null ? null : () => _choose(onConfirm),
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(
            child: DsButton(
              label: widget.cancelLabel,
              variant: DsButtonVariant.primary,
              onPressed: () => _choose(widget.onCancel),
            ),
          ),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: DsTextButton(
              label: widget.confirmLabel,
              destructive: widget.isDestructive,
              onPressed: onConfirm == null ? null : () => _choose(onConfirm),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: DsButton(
            label: widget.cancelLabel,
            variant: DsButtonVariant.secondary,
            onPressed: () => _choose(widget.onCancel),
          ),
        ),
        SizedBox(width: context.spacingSm),
        Expanded(
          child: DsButton(
            label: widget.confirmLabel,
            variant: widget.isDestructive
                ? DsButtonVariant.destructive
                : DsButtonVariant.primary,
            onPressed: onConfirm == null ? null : () => _choose(onConfirm),
          ),
        ),
      ],
    );
  }
}

double _singleLineTextWidth(
  String text,
  TextStyle? style,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
