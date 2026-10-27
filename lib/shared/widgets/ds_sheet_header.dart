import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'ds_bottom_sheet_handle.dart';
import 'ds_icon_button.dart';
import '../theme/app_text_styles.dart';
import 'ds_divider.dart';

/// Testata dei bottom sheet: handle, titolo, divisore.
///
/// La usano i sheet di scelta ([DsPickerSheet]) e di azioni, che si chiudono
/// toccando un'opzione, e i fogli con campi del nuovo disegno (tappa, scheda
/// oggetto), che passano [onClose], anche attraverso [DsFormSheet].
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
                  style: Theme.of(context).textTheme.titleLarge?.title,
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.title,
                      ),
                    ),
                    ...actions,
                    DsIconButton(
                      key: const Key('sheet_close'),
                      icon: Icons.close,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: onClose,
                    ),
                  ],
                ),
        ),
        const DsDivider(),
      ],
    );
  }
}
