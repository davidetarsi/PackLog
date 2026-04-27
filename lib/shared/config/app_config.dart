/// File per le API keys e le costanti pubbliche dell'applicazione.
/// IMPORTANTE: Questo file NON deve essere caricato su Git.
/// Contiene chiavi API sensibili.
library;

class AppConfig {
  AppConfig._();

  /// API Key per Geoapify (geocoding e autocomplete località)
  /// Documentazione: https://www.geoapify.com/
  static const String geoapify = String.fromEnvironment(
    'GEOAPIFY_KEY',
    defaultValue: 'MISSING_GEOAPIFY_KEY',
  );

  /// API Key per Remove.bg (rimozione background immagini)
  /// Documentazione: https://www.remove.bg/api
  static const String removeBg = String.fromEnvironment(
    'REMOVE_BG_KEY',
    defaultValue: 'MISSING_REMOVE_BG_KEY',
  );

  /// API Key per OpenAI (GPT-4o Vision)
  /// Documentazione: https://platform.openai.com/docs
  static const String openAi = String.fromEnvironment(
    'OPENAI_KEY',
    defaultValue: 'MISSING_OPENAI_KEY',
  );

  /// URL del questionario Google per segnalare errori o inviare suggerimenti.
  /// Modificare questo valore per puntare al proprio form.
  static const String feedbackUrl = 
      'https://docs.google.com/forms/d/e/1FAIpQLScKqaRKMwmwfi6Fq51-1z6SlZezeuB2q7kDyEr-BBDZwGocKQ/viewform';

  /// URL della repository GitHub del progetto.
  static const String githubUrl =
      'https://github.com/davidetarsi/PackLog';

  static void validate() {
    if (geoapify.isEmpty) {
      throw StateError('Errore di Build: GEO_API_KEY non definita.');
    }
  }
}
