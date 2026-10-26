import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import 'ds_button.dart';
import 'ds_sheet_header.dart';

/// Route comune dei moduli. Lo swipe del modal usa Navigator.pop e aggira
/// PopScope: si chiude con la x, il tasto indietro o il tocco esterno.
Future<T?> showDsFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  builder: builder,
);

/// Cornice dei moduli: chiusura in testata, contenuto scorrevole e una CTA.
/// Durante una scrittura impedisce chiusura e modifiche ai campi.
class DsFormSheet extends StatelessWidget {
  const DsFormSheet({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onSubmit,
    this.actionKey,
    this.isBusy = false,
    this.actions = const [],
    this.footer,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onSubmit;
  final Key? actionKey;
  final bool isBusy;
  final List<Widget> actions;

  /// Piè fisso al posto della CTA singola (per due bottoni o un avviso). Ha la
  /// precedenza su [actionLabel].
  final Widget? footer;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !isBusy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.modalBorderRadius),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.spacingMd),
                  child: AbsorbPointer(absorbing: isBusy, child: child),
                ),
              ),
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
                    onPressed: onSubmit,
                    isLoading: isBusy,
                    expand: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
