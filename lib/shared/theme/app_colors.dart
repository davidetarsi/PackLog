import 'package:flutter/material.dart';

/// Colori semantici dell'app.
/// Usa questi colori per stati specifici che non cambiano con light/dark mode.
/// Per colori che devono adattarsi, usa Theme.of(context).colorScheme
abstract class AppColors {
  // === Stati degli item ===

  /// Item attualmente in viaggio (assente dalla casa)
  static const Color itemOnTrip = Color(0xFFF57C00);
  static const Color itemOnTripLight = Color(0xFFFFF3E0);
  static const Color itemOnTripDark = Color(0xFFE65100);

  /// Item temporaneamente presente (in arrivo da un viaggio)
  static const Color itemTemporary = Color(0xFF1976D2);
  static const Color itemTemporaryLight = Color(0xFFE3F2FD);
  static const Color itemTemporaryDark = Color(0xFF0D47A1);

  // === Azioni ===

  /// Colore per azioni distruttive (elimina, rimuovi)
  static const Color destructive = Color(0xFFD32F2F);
  static const Color destructiveLight = Color(0xFFEF9A9A);

  /// Colore per successo/conferma
  static const Color success = Color(0xFF388E3C);

  /// Colore per avvisi/warning
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFE0B2);

  // === Colori neutri ===

  /// Colore per testo/icone disabilitati o secondari
  static const Color disabled = Color(0xFF9E9E9E);
  static const Color hint = Color(0xFF757575);

  /// Colore bianco per testo su sfondi colorati
  static const Color onColored = Color(0xFFFFFFFF);

  /// Bordi e separatori
  static const Color border = Color(0xFFE0E0E0);

  // === Badge e indicatori ===

  /// Badge quantità selezionata
  static const Color badgeSelected = Color(0xFFE8DEF8);
  static const Color badgeSelectedText = Color.fromARGB(255, 50, 127, 204);

  /// Badge quantità non selezionata
  static const Color badgeUnselected = Color(0xFFE7E0EC);
  static const Color badgeUnselectedText = Color(0xFF49454F);
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
    itemOnTrip: AppColors.itemOnTrip,
    itemOnTripBackground: AppColors.itemOnTripLight,
    itemOnTripText: AppColors.itemOnTripDark,
    itemTemporary: AppColors.itemTemporary,
    itemTemporaryBackground: AppColors.itemTemporaryLight,
    itemTemporaryText: AppColors.itemTemporaryDark,
  );

  /// Colori per dark mode
  static const dark = AppColorsExtension(
    itemOnTrip: Color(0xFFFFB74D),
    itemOnTripBackground: Color(0xFF3E2723),
    itemOnTripText: Color(0xFFFFCC80),
    itemTemporary: Color(0xFF64B5F6),
    itemTemporaryBackground: Color(0xFF0D47A1),
    itemTemporaryText: Color(0xFF90CAF9),
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
