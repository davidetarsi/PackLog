/// File per le API keys dell'applicazione.
/// IMPORTANTE: Questo file NON deve essere caricato su Git.
/// Contiene chiavi API sensibili.
library;

class AppConfig {
  AppConfig._();

  /// API Key per Geoapify (geocoding e autocomplete località)
  /// Documentazione: https://www.geoapify.com/
  static const String geoapify = String.fromEnvironment(
    'GEOAPIFY_KEY',
    defaultValue: '0ed95eb1ce9e47a4baa2215f61db8e69',
    );

    static void validate() {
    if (geoapify.isEmpty) {
      throw StateError('Errore di Build: GEO_API_KEY non definita.');
    }
  }
}
