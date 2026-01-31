import 'package:flutter/material.dart';

/// Colori semantici dell'app.
/// Usa questi colori per stati specifici che non cambiano con light/dark mode.
/// Per colori che devono adattarsi, usa Theme.of(context).colorScheme
abstract class AppColors {
  // === Colori principali del tema ===

  /// Arancione scuro - colore principale dell'app
  static const Color primaryOrange = Color.fromARGB(255, 214, 103, 49);
  static const Color primaryOrangeLight = Color.fromARGB(255, 247, 144, 92);
  static const Color primaryOrangeDark = primaryOrange;

  // === Stati degli item ===

  /// Item attualmente in viaggio (assente dalla casa) - usa arancione del tema
  static const Color itemOnTrip = Color(0xFFFF8A50);
  static const Color itemOnTripLight = Color(0xFF3D2000);
  static const Color itemOnTripDark = Color(0xFFE65100);

  /// Item temporaneamente presente (in arrivo da un viaggio) - usa blu/azzurro
  static const Color itemTemporary = Color(0xFF42A5F5);
  static const Color itemTemporaryLight = Color(0xFF1A3A5C);
  static const Color itemTemporaryDark = Color(0xFF1976D2);

  // === Azioni ===

  /// Colore per azioni distruttive (elimina, rimuovi)
  static const Color destructive = Color(0xFFCF6679);
  static const Color destructiveLight = Color(0xFF5C2A2A);

  /// Colore per successo/conferma
  static const Color success = Color(0xFF4CAF50);

  /// Colore per avvisi/warning - usa arancione
  static const Color warning = Color(0xFFFF8A50);
  static const Color warningLight = Color(0xFF3D2000);

  // === Colori neutri ===

  /// Colore per testo/icone disabilitati o secondari
  static const Color disabled = Color(0xFF6E6E6E);
  static const Color hint = Color(0xFF9E9E9E);

  /// Colore bianco per testo su sfondi colorati
  static const Color onColored = Color(0xFFFFFFFF);

  /// Bordi e separatori
  static const Color border = Color(0xFF3A3A3A);

  // === Badge e indicatori ===

  /// Badge quantità selezionata - usa arancione
  static const Color badgeSelected = Color(0xFF3D2000);
  static const Color badgeSelectedText = Color(0xFFFF8A50);

  /// Badge quantità non selezionata
  static const Color badgeUnselected = Color(0xFF2D2D2D);
  static const Color badgeUnselectedText = Color(0xFFB0B0B0);
}

/// Extension del tema per colori custom che supportano light/dark mode
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color itemOnTrip;
  final Color itemOnTripBackground;
  final Color itemOnTripText;
  final Color itemTemporary;
  final Color itemTemporaryBackground;
  final Color itemTemporaryText;

  const AppColorsExtension({
    required this.itemOnTrip,
    required this.itemOnTripBackground,
    required this.itemOnTripText,
    required this.itemTemporary,
    required this.itemTemporaryBackground,
    required this.itemTemporaryText,
  });

  /// Colori per light mode
  static const light = AppColorsExtension(
    itemOnTrip: AppColors.itemOnTripDark,
    itemOnTripBackground: Color(0xFFFFF3E0),
    itemOnTripText: AppColors.itemOnTripDark,
    itemTemporary: AppColors.itemTemporaryDark,
    itemTemporaryBackground: Color(0xFFE3F2FD),
    itemTemporaryText: AppColors.itemTemporaryDark,
  );

  /// Colori per dark mode - usa arancione del tema
  static const dark = AppColorsExtension(
    itemOnTrip: AppColors.itemOnTrip, // Arancione chiaro
    itemOnTripBackground: AppColors.itemOnTripLight, // Sfondo arancione scuro
    itemOnTripText: AppColors.itemOnTrip,
    itemTemporary: AppColors.itemTemporary, // Blu chiaro
    itemTemporaryBackground: AppColors.itemTemporaryLight, // Sfondo blu scuro
    itemTemporaryText: AppColors.itemTemporary,
  );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? itemOnTrip,
    Color? itemOnTripBackground,
    Color? itemOnTripText,
    Color? itemTemporary,
    Color? itemTemporaryBackground,
    Color? itemTemporaryText,
  }) {
    return AppColorsExtension(
      itemOnTrip: itemOnTrip ?? this.itemOnTrip,
      itemOnTripBackground: itemOnTripBackground ?? this.itemOnTripBackground,
      itemOnTripText: itemOnTripText ?? this.itemOnTripText,
      itemTemporary: itemTemporary ?? this.itemTemporary,
      itemTemporaryBackground:
          itemTemporaryBackground ?? this.itemTemporaryBackground,
      itemTemporaryText: itemTemporaryText ?? this.itemTemporaryText,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      itemOnTrip: Color.lerp(itemOnTrip, other.itemOnTrip, t)!,
      itemOnTripBackground: Color.lerp(
        itemOnTripBackground,
        other.itemOnTripBackground,
        t,
      )!,
      itemOnTripText: Color.lerp(itemOnTripText, other.itemOnTripText, t)!,
      itemTemporary: Color.lerp(itemTemporary, other.itemTemporary, t)!,
      itemTemporaryBackground: Color.lerp(
        itemTemporaryBackground,
        other.itemTemporaryBackground,
        t,
      )!,
      itemTemporaryText: Color.lerp(
        itemTemporaryText,
        other.itemTemporaryText,
        t,
      )!,
    );
  }
}
