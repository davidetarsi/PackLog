import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'error_empty_theme_extension.dart';
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

  /// Tema chiaro - Palette curata con arancione su sfondo bianco/grigio chiaro
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      // Colori primari (arancione)
      primary: _primaryOrange,
      onPrimary: Color.fromARGB(255, 240, 226, 212),
      primaryContainer: Color(0xFFFFE0CC), // Arancione molto chiaro
      onPrimaryContainer: Color(0xFF5C2000),
      // Colori secondari
      secondary: Color(0xFFFF8A50),
      onSecondary: Color.fromARGB(255, 206, 205, 205),
      secondaryContainer: Color(0xFFFFE0CC),
      onSecondaryContainer: Color(0xFF5C2000),
      // Colori terziari
      tertiary: Color(0xFFFFAB73),
      onTertiary: Color.fromARGB(213, 255, 255, 255),
      // Superfici (bianco/grigio chiaro)
      surface: Color(0xFFFAFAFA), // Grigio chiarissimo
      onSurface: Color(0xFF1C1C1C),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF5F5F5),
      surfaceContainer: Color(0xFFEFEFEF),
      surfaceContainerHigh: Color(0xFFE8E8E8),
      surfaceContainerHighest: Color(0xFFE0E0E0),
      // Altri colori
      error: Color(0xFFB00020),
      onError: Colors.white,
      outline: Color(0xFFBDBDBD),
      outlineVariant: Color(0xFFE0E0E0),
      inverseSurface: Color(0xFF2D2D2D),
      onInverseSurface: Color(0xFFF5F5F5),
      inversePrimary: Color(0xFFFFAB73),
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
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
          fontSize: 24
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // === Extensions ===
      extensions: [
        appColors,
        colorScheme.brightness == Brightness.dark
            ? ErrorEmptyThemeExtension.darkDefaults
            : ErrorEmptyThemeExtension.lightDefaults,
      ],
    );
  }
}

/// Extension per accedere facilmente ai colori custom dal context
extension AppColorsExtensionX on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
