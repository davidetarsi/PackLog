import 'package:flutter/material.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';

/// Tile selezionabile per la scelta della lingua nella dialog di lingua.
///
/// Mostra bandiera, nome della lingua e un indicatore di selezione attiva.
class LanguageTile extends StatelessWidget {
  final Locale locale;
  final String title;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageTile({
    super.key,
    required this.locale,
    required this.title,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Riga leggera come quelle dei moduli: la scelta corrente ha solo la
    // spunta arancione, senza bordo né sfondo colorato.
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      ),
      leading: Text(flag, style: TextStyle(fontSize: context.iconSizeMd)),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
