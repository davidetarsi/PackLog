import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'error_empty_theme_extension.dart';
import '../constants/app_constants.dart';

/// Tema principale dell'app — Material 3, colori esplicitamente calibrati.
///
/// Principi DS (Fase 2):
/// - Nessun alpha generato a runtime per testo muted: usa onSurfaceVariant.
/// - Nessun alpha su bordi: usa outline / outlineVariant nativi.
/// - tertiary = stati transienti (es. "in viaggio"). Ambra in entrambi i temi.
/// - State layer alpha: 0.08 (hover) / 0.12 (selected) / 0.16 (dragged).
class AppTheme {
  /// Tema chiaro — arancione brand su sfondo caldo beige.
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      // ── Primary ───────────────────────────────────────────────────────────
      // #E85D04: arancione brand light. onPrimary bianco garantisce WCAG AA.
      primary: Color(0xFFE85D04),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFE0CC),
      onPrimaryContainer: Color(0xFF4A1F00),
      // ── Secondary ─────────────────────────────────────────────────────────
      // Grigio neutro per azioni secondarie, distinto dal brand orange.
      secondary: Color(0xFF6B7280),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE5E7EB),
      onSecondaryContainer: Color(0xFF1F2937),
      // ── Tertiary: stati transienti ("in viaggio") ──────────────────────────
      // Ambra brunita. Distinta da primary (arancione) e da itemTemporary (blu).
      tertiary: Color(0xFFD97706),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFEF3C7),
      onTertiaryContainer: Color(0xFF451A03),
      // ── Superfici (beige caldo) ────────────────────────────────────────────
      surface: Color(0xFFFAF5F0),
      onSurface: Color(0xFF1A1A1A),
      // onSurfaceVariant calibrato per leggibilità secondaria WCAG AA in light.
      onSurfaceVariant: Color(0xFF595959),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF5F0EC),
      surfaceContainer: Color(0xFFF0E8DD),
      surfaceContainerHigh: Color(0xFFE8DECF),
      surfaceContainerHighest: Color(0xFFDDD0BC),
      // ── Bordi ─────────────────────────────────────────────────────────────
      // outline: bordo forte (selezionato, focus). outlineVariant: divider/card.
      outline: Color(0xFFB8B8B8),
      outlineVariant: Color(0xFFE0E0E0),
      // ── Error / Inverse ───────────────────────────────────────────────────
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      inverseSurface: Color(0xFF2D2D2D),
      onInverseSurface: Color(0xFFF5F5F5),
      inversePrimary: Color(0xFFFFAB73),
    );

    return _buildTheme(colorScheme, AppColorsExtension.light);
  }

  /// Tema scuro — arancione luminoso su sfondo dark.
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      // ── Primary ───────────────────────────────────────────────────────────
      // #FF8A50: arancione brand dark (più luminoso per contrasto su dark BG).
      primary: Color(0xFFFF8A50),
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF6B2A00),
      onPrimaryContainer: Color(0xFFFFD9C2),
      // ── Secondary ─────────────────────────────────────────────────────────
      secondary: Color(0xFFA1A1AA),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF3F3F46),
      onSecondaryContainer: Color(0xFFE4E4E7),
      // ── Tertiary: stati transienti ("in viaggio") ──────────────────────────
      // Ambra luminosa per contrasto su dark surface.
      tertiary: Color(0xFFFBBF24),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF451A03),
      onTertiaryContainer: Color(0xFFFEF3C7),
      // ── Superfici (dark) ──────────────────────────────────────────────────
      surface: Color(0xFF1A1A1A),
      onSurface: Color(0xFFF5F5F5),
      // onSurfaceVariant calibrato per dark: bianco abbassato, non alpha grezzo.
      onSurfaceVariant: Color(0xFFB8B8B8),
      surfaceContainerLowest: Color(0xFF0D0D0D),
      surfaceContainerLow: Color(0xFF151515),
      surfaceContainer: Color(0xFF252525),
      surfaceContainerHigh: Color(0xFF2E2E2E),
      surfaceContainerHighest: Color(0xFF383838),
      // ── Bordi ─────────────────────────────────────────────────────────────
      outline: Color(0xFF595959),
      outlineVariant: Color(0xFF3A3A3A),
      // ── Error / Inverse ───────────────────────────────────────────────────
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      inverseSurface: Color(0xFFE8E8E8),
      onInverseSurface: Color(0xFF1E1E1E),
      inversePrimary: Color(0xFFBF360C),
    );

    return _buildTheme(colorScheme, AppColorsExtension.dark);
  }

  // Font family dell'app
  static const String fontFamily = 'sans-serif';

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    AppColorsExtension appColors,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,

      // === Card Theme ===
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
        margin: const EdgeInsets.only(bottom: 8),
      ),

      // === Input Decoration Theme ===
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // === List Tile Theme ===
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // === Elevated Button Theme ===
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
        ),
      ),

      // === Outlined Button Theme ===
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
        ),
      ),

      // === Filled Button Theme ===
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
        ),
      ),

      // === Divider Theme ===
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),

      // === App Bar Theme ===
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        // ≥ 24px → w600 (regola DS size→weight Fase 3)
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          fontSize: AppSpacing.fontTitle,
        ),
      ),

      // === Bottom Sheet Theme ===
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: colorScheme.surface,
      ),

      // === Dialog Theme ===
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.modalBorderRadius),
        ),
      ),

      // === Extensions ===
      extensions: [
        appColors,
        // ErrorEmptyThemeExtension calcolata dal ColorScheme attivo
        // (no dipendenza da AppColors statici).
        ErrorEmptyThemeExtension(
          emptyStateTitle: TextStyle(
            fontSize: AppSpacing.fontLg,   // 20px → w700 se titolo hero, w400 per stato vuoto
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
          emptyStateSubtitle: TextStyle(
            fontSize: AppSpacing.fontSm,   // 16px → body → w400
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
          emptyStateIconSize: 80,
          emptyStateIconColor: colorScheme.onSurface.withValues(alpha: 0.38),
          emptyStateTitleColor: colorScheme.onSurfaceVariant,
          emptyStateSubtitleColor: colorScheme.onSurfaceVariant,
          errorStateMessage: const TextStyle(
            fontSize: AppSpacing.fontSm,
            fontWeight: FontWeight.w400,
          ),
          errorStateIconSize: 80,
          errorStateIconColor: colorScheme.error,
          errorStateRetryLabel: 'common.retry',
          stateSpacingMd: 16,
          stateSpacingLg: 24,
          stateSpacingSm: 8,
        ),
      ],
    );
  }
}

/// Extension per accedere facilmente ai colori custom dal context
extension AppColorsExtensionX on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
