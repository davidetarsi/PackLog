class AppConstants {
  static const String housesKey = 'houses';
  static const String itemsKey = 'items';
  static const String tripsKey = 'trips';

  // Backup Constants
  /// Prefisso per i file di backup del database
  static const String backupFilePrefix = 'stuff-tracker-db';
  
  /// Estensione per i file di database
  static const String databaseFileExtension = '.db';

  // UI Constants
  /// Border radius for cards (16.0)
  static const double cardBorderRadius = 16.0;

  /// Border radius for pill-shaped elements (fully rounded: 30.0)
  static const double pillBorderRadius = 30.0;

  /// Border radius for input fields (TextFormField, Dropdown, etc.: 12.0)
  static const double inputBorderRadius = 12.0;

  /// Border radius for badges and small UI elements (8.0)
  static const double badgeBorderRadius = 8.0;

  /// Border radius for dialogs and modals (20.0)
  static const double modalBorderRadius = 20.0;

  /// Padding inferiore per le liste con floating navigation bar
  static const double floatingNavBarPadding = 80.0;

  /// Padding inferiore per le bottom sheet (evita sovrapposizione con elementi sotto)
  static const double bottomSheetBottomPadding = 24.0;
}
