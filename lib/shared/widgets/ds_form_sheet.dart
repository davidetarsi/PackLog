import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import 'ds_button.dart';
import 'ds_sheet_header.dart';

/// Apre un foglio dal basso sul Navigator radice, con le stesse opzioni per
/// tutti i fogli. Con [enableDrag] lo swipe chiude il foglio.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool enableDrag = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  enableDrag: enableDrag,
  backgroundColor: Colors.transparent,
  builder: builder,
);

/// Route comune dei moduli. Lo swipe del modal usa Navigator.pop e aggira
/// PopScope: si chiude con la x, il tasto indietro o il tocco esterno.
Future<T?> showDsFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDsSheet<T>(context, builder: builder, enableDrag: false);

/// Cornice dei moduli: chiusura in testata, contenuto scorrevole e una CTA.
/// Durante una scrittura impedisce chiusura e modifiche ai campi.
class DsFormSheet extends StatelessWidget {
  const DsFormSheet({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.actionIcon,
    this.onSubmit,
    this.actionKey,
    this.isBusy = false,
    this.actions = const [],
    this.footer,
    this.padding,
    this.expand = false,
  });

  final String title;
  final Widget child;
  final String? actionLabel;

  /// Icona della CTA, prima dell'etichetta.
  final IconData? actionIcon;
  final VoidCallback? onSubmit;
  final Key? actionKey;
  final bool isBusy;
  final List<Widget> actions;

  /// Piè fisso al posto della CTA singola (per due bottoni o un avviso). Ha la
  /// precedenza su [actionLabel].
  final Widget? footer;

  /// Padding del contenuto. `null` vale `EdgeInsets.all(context.spacingMd)`.
  final EdgeInsetsGeometry? padding;

  /// Il foglio prende tutta l'altezza massima e il contenuto riempie lo spazio
  /// tra testata e CTA, senza scroll esterno né padding: per i contenuti che
  /// scorrono da soli, come il calendario.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        AppConstants.sheetMaxHeightFactor *
        (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom);

    final body = expand
        ? Expanded(
            child: AbsorbPointer(absorbing: isBusy, child: child),
          )
        : Flexible(
            child: SingleChildScrollView(
              padding: padding ?? EdgeInsets.all(context.spacingMd),
              child: AbsorbPointer(absorbing: isBusy, child: child),
            ),
          );

    final frame = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AbsorbPointer(
              absorbing: isBusy,
              child: DsSheetHeader(
                title: title,
                actions: actions,
                onClose: () => Navigator.pop(context),
              ),
            ),
            body,
            if (footer != null)
              footer!
            else if (actionLabel != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacingMd,
                  0,
                  context.spacingMd,
                  context.spacingMd,
                ),
                child: DsButton(
                  key: actionKey,
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onSubmit,
                  isLoading: isBusy,
                  expand: true,
                ),
              ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !isBusy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: expand
            ? SizedBox(height: maxHeight, child: frame)
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: frame,
              ),
      ),
    );
  }
}
