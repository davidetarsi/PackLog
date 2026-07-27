library;

class AppConfig {
  AppConfig._();

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

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: 'MISSING_GOOGLE_WEB_CLIENT_ID',
  );

  /// URL del questionario Google per segnalare errori o inviare suggerimenti.
  static const String feedbackUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLScKqaRKMwmwfi6Fq51-1z6SlZezeuB2q7kDyEr-BBDZwGocKQ/viewform';

  /// URL della repository GitHub del progetto.
  static const String githubUrl = 'https://github.com/davidetarsi/PackLog';

  /// URL pubblico della Privacy Policy. Mostrato come link nel checkbox di
  /// consenso in [LoginScreen] e obbligatorio per la scheda Play Store.
  /// Placeholder finché la pagina non è hostata (vedi docs/legal-hosting-checklist.md).
  static const String privacyPolicyUrl =
      'https://packlog.app/privacy';

  /// URL pubblico dei Termini di Servizio. Mostrato come link nel checkbox di
  /// consenso in [LoginScreen]. Placeholder finché la pagina non è hostata.
  static const String termsOfServiceUrl =
      'https://packlog.app/terms';

  static void validate() {
    final missing = <String>[];
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
    if (amplitudeApiKey.isEmpty ||
        amplitudeApiKey == 'MISSING_AMPLITUDE_API_KEY') {
      missing.add('AMPLITUDE_API_KEY');
    }
    if (googleWebClientId.isEmpty ||
        googleWebClientId == 'MISSING_GOOGLE_WEB_CLIENT_ID') {
      missing.add('GOOGLE_WEB_CLIENT_ID');
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'Errore di Build: variabili mancanti: ${missing.join(', ')}',
      );
    }
  }
}
