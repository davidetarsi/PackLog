import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'ds_bottom_sheet_handle.dart';

/// Testata dei bottom sheet senza form: handle, titolo, divisore.
///
/// I sheet con form hanno la loro testata in [StandardBottomSheetLayout], con
/// il bottone chiudi. Questa serve ai sheet di scelta ([DsPickerSheet]) e di
/// azioni, che si chiudono toccando un'opzione.
class DsSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const DsSheetHeader({super.key, required this.title, this.onClose});

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
