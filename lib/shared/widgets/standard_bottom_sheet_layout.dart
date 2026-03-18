import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../helpers/bottom_sheet_handle.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import 'universal_action_bar.dart';
import 'circular_action_button.dart';

/// Layout standardizzato per tutti i bottom sheet dell'app.
/// 
/// Fornisce:
/// - Handle superiore per drag
/// - Titolo con bottone chiudi
/// - Contenuto scrollabile con gestione keyboard
/// - Bottoni Annulla/Salva standardizzati
/// 
/// Esempio:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (context) => StandardBottomSheetLayout(
///     title: 'Nuovo Oggetto',
///     onCancel: () => Navigator.pop(context),
///     onSave: () async { /* save logic */ },
///     isLoading: false,
///     child: Column(
///       children: [
///         TextField(...),
///         // other form fields
///       ],
///     ),
///   ),
/// );
/// ```
class StandardBottomSheetLayout extends StatelessWidget {
  /// Titolo del bottom sheet
  final String title;

  /// Contenuto del bottom sheet (form fields)
  final Widget child;

  /// Callback quando si preme Annulla o la X
  final VoidCallback onCancel;

  /// Callback quando si preme Salva
  final VoidCallback onSave;

  /// Se true, mostra loading e disabilita i bottoni
  final bool isLoading;

  /// Etichetta personalizzata per il bottone salva (default: "Salva")
  final String? saveLabel;

  /// Se true, mostra il bottone annulla (default: true)
  final bool showCancelButton;

  const StandardBottomSheetLayout({
    super.key,
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onSave,
    this.isLoading = false,
    this.saveLabel,
    this.showCancelButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const BottomSheetHandle(),

            // Header con titolo e bottone chiudi
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: isLoading ? null : onCancel,
                    icon: Icon(Icons.close, size: context.iconSizeMd),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Contenuto scrollabile
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.spacingMd,
                  context.spacingMd,
                  context.spacingMd,
                  context.spacingSm,
                ),
                child: child,
              ),
            ),

            // Action bar standardizzata
            Padding(
              padding: EdgeInsets.only(
                left: context.spacingMd,
                right: context.spacingMd,
                top: context.spacingMd,
                bottom: context.spacingMd + AppConstants.bottomSheetBottomPadding,
              ),
              child: UniversalActionBar(
                horizontalPadding: 0,
                primaryLabel: saveLabel ?? 'common.save'.tr(),
                primaryIcon: Icons.save,
                onPrimaryPressed: isLoading ? null : onSave,
                isLoading: isLoading,
                leftAction: showCancelButton
                    ? CircularActionButton(
                        icon: Icons.close,
                        onPressed: isLoading ? null : onCancel,
                        showBorder: true,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
