import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../constants/app_constants.dart';

/// Tema principale dell'app.
/// Definisce tutti gli stili globali per avere un design consistente.
class AppTheme {
  /// Tema chiaro
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 50, 127, 204),
      brightness: Brightness.light,
    );

    return _buildTheme(colorScheme, AppColorsExtension.light);
  }

  /// Tema scuro
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 50, 127, 204),
      brightness: Brightness.dark,
    );

    return _buildTheme(colorScheme, AppColorsExtension.dark);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    AppColorsExtension appColors,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

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
