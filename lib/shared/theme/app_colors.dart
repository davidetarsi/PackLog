import 'package:flutter/material.dart';

/// Colori statici immutabili dell'app.
///
/// ⚠️  NOTA DI MIGRAZIONE (DS Fase 2) ─────────────────────────────────────────
/// La maggior parte delle costanti qui sotto sono in corso di dismissione.
/// Il loro ruolo è assorbito da:
///   • ColorScheme  (primary, secondary, tertiary, error, outline…)
///   • AppColorsExtension  (itemTemporary, success, warning)
///
/// Costanti ancora valide (brand, non migrate):
///   - onColored: Colors.white (testo su sfondi colorati puri)
///   - itemTemporary*: usati solo nell'AppColorsExtension, non direttamente.
///
/// Regola: usa sempre context.colorScheme.X o context.appColors.X nei widget.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class AppColors {
  /// Testo bianco su sfondi colorati (brand use only).
  static const Color onColored = Colors.white;

  // ── Item Temporary (blu ospite) ──────────────────────────────────────────
  // Mantenuto come costante interna per AppColorsExtension.
  // Non usare direttamente nei widget → usa context.appColors.itemTemporary.
  static const Color itemTemporary = Color(0xFF42A5F5);
  static const Color itemTemporaryBackground = Color(0xFFE3F2FD);
  static const Color itemTemporaryText = Color(0xFF0D47A1);
  static const Color itemTemporaryBackgroundDark = Color(0xFF1A3A5C);
  static const Color itemTemporaryTextDark = Color(0xFF82B1FF);

  // ── Deprecated ───────────────────────────────────────────────────────────
  // Usare colorScheme.primary, .tertiary, .error, .onSurfaceVariant al posto.

  @Deprecated('Usa colorScheme.primary dal tema. DS Fase 2.')
  static const Color primaryOrangeLight = Color(0xFFF76415);

  @Deprecated('Usa colorScheme.primary dal tema. DS Fase 2.')
  static const Color primaryOrangeDark = Color(0xFFF76415);

  @Deprecated('Usa colorScheme.tertiary/tertiaryContainer. DS Fase 2.')
  static const Color itemOnTrip = Color(0xFFFF8A50);

  @Deprecated('Usa colorScheme.tertiaryContainer. DS Fase 2.')
  static const Color itemOnTripLight = Color(0xFF3D2000);

  @Deprecated('Usa colorScheme.onTertiaryContainer. DS Fase 2.')
  static const Color itemOnTripDark = Color(0xFFE65100);

  @Deprecated('Usa colorScheme.error dal tema. DS Fase 2.')
  static const Color destructive = Color(0xFFCF6679);

  @Deprecated('Usa colorScheme.error dal tema. DS Fase 2.')
  static const Color destructiveLight = Color(0xFF5C2A2A);

  @Deprecated('Usa context.appColors.success. DS Fase 2.')
  static const Color success = Color(0xFF4CAF50);

  @Deprecated('Usa context.appColors.warning. DS Fase 2.')
  static const Color warning = Color(0xFFFF8A50);

  @Deprecated('Usa context.appColors.warning. DS Fase 2.')
  static const Color warningLight = Color(0xFF3D2000);

  @Deprecated('Usa colorScheme.onSurface.withValues(alpha: 0.38). DS Fase 2.')
  static const Color disabled = Color(0xFF6E6E6E);

  @Deprecated('Usa colorScheme.onSurfaceVariant. DS Fase 2.')
  static const Color hint = Color(0xFF9E9E9E);

  @Deprecated('Usa colorScheme.outline. DS Fase 2.')
  static const Color border = Color(0xFF3A3A3A);

  @Deprecated('Usa colorScheme.primaryContainer / onPrimaryContainer. DS Fase 2.')
  static const Color badgeSelected = Color(0xFF3D2000);

  @Deprecated('Usa colorScheme.primaryContainer / onPrimaryContainer. DS Fase 2.')
  static const Color badgeSelectedText = Color(0xFFFF8A50);

  @Deprecated('Usa colorScheme.surfaceContainerHighest / onSurfaceVariant. DS Fase 2.')
  static const Color badgeUnselected = Color(0xFF2D2D2D);

  @Deprecated('Usa colorScheme.surfaceContainerHighest / onSurfaceVariant. DS Fase 2.')
  static const Color badgeUnselectedText = Color(0xFFB0B0B0);
}

/// Extension del tema per i colori semantici custom che non rientrano in Material 3.
///
/// Contiene solo colori che richiedono valori distinti per light/dark e che
/// non hanno un equivalente diretto in ColorScheme:
///   - itemTemporary: blu "ospite/temporaneo" (distinto da tertiary "in viaggio")
///   - success: verde conferma/completamento (tema-aware)
///   - warning: ambra avviso (tema-aware, distinto dal brand orange)
///
/// Accesso: context.appColors.success, context.appColors.itemTemporary, ecc.
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  // ── Success ──────────────────────────────────────────────────────────────
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  // ── Warning ───────────────────────────────────────────────────────────────
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  // ── Item Temporary (ospite/in arrivo) ─────────────────────────────────────
  // Mantenuto custom perché deve restare DISTINTO da tertiary ("in viaggio").
  // Vedi DS Fase 2 §2.4 — decisione di non mappare su tertiary.
  final Color itemTemporary;
  final Color itemTemporaryBackground;
  final Color itemTemporaryText;

  const AppColorsExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.itemTemporary,
    required this.itemTemporaryBackground,
    required this.itemTemporaryText,
  });

  /// Valori per light mode.
  static const light = AppColorsExtension(
    // Verde Material calibrato per light (contrasto bianco > 4.5:1)
    success: Color(0xFF2E7D32),
    onSuccess: Colors.white,
    successContainer: Color(0xFFE8F5E9),
    onSuccessContainer: Color(0xFF1B5E20),
    // Ambra avviso — leggibile su sfondo chiaro
    warning: Color(0xFFB45309),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF451A03),
    // Blu ospite/temporaneo — distinto da tertiary (ambra) e da primary (arancione)
    itemTemporary: Color(0xFF1976D2),
    itemTemporaryBackground: Color(0xFFE3F2FD),
    itemTemporaryText: Color(0xFF0D47A1),
  );

  /// Valori per dark mode.
  static const dark = AppColorsExtension(
    // Verde più luminoso per contrasto su dark surface
    success: Color(0xFF66BB6A),
    onSuccess: Colors.black,
    successContainer: Color(0xFF1B5E20),
    onSuccessContainer: Color(0xFFC8E6C9),
    // Ambra più luminosa per dark
    warning: Color(0xFFFFCA28),
    onWarning: Colors.black,
    warningContainer: Color(0xFF663C00),
    onWarningContainer: Color(0xFFFFF3CD),
    // Blu ospite — stesso tono, background più scuro
    itemTemporary: Color(0xFF42A5F5),
    itemTemporaryBackground: Color(0xFF1A3A5C),
    itemTemporaryText: Color(0xFF82B1FF),
  );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? itemTemporary,
    Color? itemTemporaryBackground,
    Color? itemTemporaryText,
  }) {
    return AppColorsExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
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
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      itemTemporary: Color.lerp(itemTemporary, other.itemTemporary, t)!,
      itemTemporaryBackground:
          Color.lerp(itemTemporaryBackground, other.itemTemporaryBackground, t)!,
      itemTemporaryText:
          Color.lerp(itemTemporaryText, other.itemTemporaryText, t)!,
    );
  }
}
