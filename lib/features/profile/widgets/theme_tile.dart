import 'package:flutter/material.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';

/// Tile selezionabile per la scelta del tema nella dialog di tema.
///
/// Mostra icona, nome del tema e un indicatore di selezione attiva.
class ThemeTile extends StatelessWidget {
  final ThemeMode mode;
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemeTile({
    super.key,
    required this.mode,
    required this.title,
    required this.icon,
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
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
