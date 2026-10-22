import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'ds_bottom_sheet_handle.dart';

/// Testata dei bottom sheet: handle, titolo, divisore.
///
/// La usano i sheet di scelta ([DsPickerSheet]) e di azioni, che si chiudono
/// toccando un'opzione, e i fogli con campi del nuovo disegno (tappa, scheda
/// oggetto), che passano [onClose]. Il vecchio [StandardBottomSheetLayout] ha
/// la sua testata.
class DsSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  /// Azioni prima della "x", che resta all'estrema destra: come il menu ⋮ della
  /// scheda oggetto. Solo con [onClose].
  final List<Widget> actions;

  const DsSheetHeader({
    super.key,
    required this.title,
    this.onClose,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: DsBottomSheetHandle()),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: onClose == null
              ? Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...actions,
                    IconButton(
                      key: const Key('sheet_close'),
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: onClose,
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
