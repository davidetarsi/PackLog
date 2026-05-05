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

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'MISSING_SUPABASE_URL',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'MISSING_SUPABASE_ANON_KEY',
  );

  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: 'MISSING_SENTRY_DSN',
  );

  static const String amplitudeApiKey = String.fromEnvironment(
    'AMPLITUDE_API_KEY',
    defaultValue: 'MISSING_AMPLITUDE_API_KEY',
  );

  /// URL del questionario Google per segnalare errori o inviare suggerimenti.
  static const String feedbackUrl = 
      'https://docs.google.com/forms/d/e/1FAIpQLScKqaRKMwmwfi6Fq51-1z6SlZezeuB2q7kDyEr-BBDZwGocKQ/viewform';

  /// URL della repository GitHub del progetto.
  static const String githubUrl =
      'https://github.com/davidetarsi/PackLog';

  static void validate() {
    final missing = <String>[];
    if (geoapify.isEmpty || geoapify == 'MISSING_GEOAPIFY_KEY') {
      missing.add('GEOAPIFY_KEY');
    }
    if (supabaseUrl.isEmpty || supabaseUrl == 'MISSING_SUPABASE_URL') {
      missing.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.isEmpty ||
        supabaseAnonKey == 'MISSING_SUPABASE_ANON_KEY') {
      missing.add('SUPABASE_ANON_KEY');
    }
    if (sentryDsn.isEmpty || sentryDsn == 'MISSING_SENTRY_DSN') {
      missing.add('SENTRY_DSN');
    }
    if (amplitudeApiKey.isEmpty || amplitudeApiKey == 'MISSING_AMPLITUDE_API_KEY') {
      missing.add('AMPLITUDE_API_KEY');
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'Errore di Build: variabili mancanti: ${missing.join(', ')}',
      );
    }
  }
}
