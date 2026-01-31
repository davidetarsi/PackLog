import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../constants/app_constants.dart';

/// Tema principale dell'app.
/// Definisce tutti gli stili globali per avere un design consistente.
class AppTheme {
  // === Colori principali del tema ===
  static const Color _primaryOrange = Color.fromARGB(
    255,
    247,
    100,
    21,
  ); // Arancione scuro
  static const Color _primaryOrangeLight = Color(0xFFFF8A50);
  static const Color _surfaceDark = Color(0xFF121212); // Nero
  static const Color _surfaceContainerDark = Color(
    0xFF1E1E1E,
  ); // Grigio molto scuro
  static const Color _surfaceContainerHighDark = Color(
    0xFF2D2D2D,
  ); // Grigio scuro

  /// Tema chiaro (fallback, ma l'app userà principalmente il dark)
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryOrange,
      brightness: Brightness.light,
    );

    return _buildTheme(colorScheme, AppColorsExtension.light);
  }

  /// Tema scuro - Tema principale dell'app
  static ThemeData get dark {
    // ColorScheme personalizzato per tema scuro con arancione
    const colorScheme = ColorScheme.dark(
      // Colori primari (arancione)
      primary: _primaryOrange,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3D2000),
      onPrimaryContainer: _primaryOrangeLight,
      // Colori secondari
      secondary: Color(0xFFFFB74D),
      onSecondary: Color(0xFF1E1E1E),
      secondaryContainer: Color(0xFF4A3000),
      onSecondaryContainer: Color(0xFFFFDDB0),
      // Colori terziari
      tertiary: Color(0xFFFFCC80),
      onTertiary: Color(0xFF1E1E1E),
      // Superfici (nero/grigio scuro)
      surface: _surfaceDark,
      onSurface: Color(0xFFE8E8E8),
      surfaceContainerLowest: Color(0xFF0D0D0D),
      surfaceContainerLow: Color(0xFF1A1A1A),
      surfaceContainer: _surfaceContainerDark,
      surfaceContainerHigh: _surfaceContainerHighDark,
      surfaceContainerHighest: Color(0xFF3A3A3A),
      // Altri colori
      error: Color(0xFFCF6679),
      onError: Colors.black,
      outline: Color(0xFF5C5C5C),
      outlineVariant: Color(0xFF3A3A3A),
      inverseSurface: Color(0xFFE8E8E8),
      onInverseSurface: Color(0xFF1E1E1E),
      inversePrimary: Color(0xFFBF360C),
    );

    return _buildTheme(colorScheme, AppColorsExtension.dark);
  }

  // Font family dell'app
  static const String fontFamily = 'serif';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // === Extensions ===
      extensions: [appColors],
    );
  }
}

/// Extension per accedere facilmente ai colori custom dal context
extension AppColorsExtensionX on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
