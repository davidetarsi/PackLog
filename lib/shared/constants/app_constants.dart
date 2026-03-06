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
  static const double cardBorderRadius = 12.0;

  /// Raggio per card a pillola (bordi completamente arrotondati)
  static const double pillBorderRadius = 30.0;

  /// Raggio per i campi di input (TextFormField, Dropdown, etc.)
  static const double inputBorderRadius = 12.0;

  /// Padding inferiore per le liste con floating navigation bar
  static const double floatingNavBarPadding = 80.0;

  /// Padding inferiore per le bottom sheet (evita sovrapposizione con elementi sotto)
  static const double bottomSheetBottomPadding = 24.0;
}
