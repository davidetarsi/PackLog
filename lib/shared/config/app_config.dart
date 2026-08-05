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

  /// Project key di tgram-analytics (formato `proj_…`).
  ///
  /// L'SDK viene inizializzato **solo in [Environment.prod]** (vedi
  /// `_initNonCriticalServices` in `bootstrap.dart`): il piano free ha quota
  /// 1 progetto, quindi lo stream è riservato agli eventi reali e le build
  /// dev non lo inquinano. La chiave resta comunque definita in dev perché
  /// [validate] la richiede in modo uniforme.
  static const String tgramApiKey = String.fromEnvironment(
    'TGRAM_API_KEY',
    defaultValue: 'MISSING_TGRAM_API_KEY',
  );

  /// Endpoint dell'istanza managed di tgram-analytics.
  static const String tgramServerUrl = 'https://api.tgram-analytics.com';

  /// Forza l'init di tgram-analytics anche fuori da [Environment.prod].
  ///
  /// Esiste perché il login Google funziona solo con coppie
  /// `(applicationId, SHA-1)` registrate su Google Cloud: la build prod
  /// richiede il keystore di release, disponibile solo in CI. Senza questo
  /// flag le analytics sarebbero verificabili unicamente dopo una release
  /// vera — cioè in produzione, sugli utenti.
  ///
  /// Da riga di comando:
  /// ```bash
  /// flutter run --flavor dev -t lib/main_dev.dart \
  ///   --dart-define=TGRAM_FORCE_ENABLE=true ...
  /// ```
  ///
  /// Default `false`: le build dev restano mute e non inquinano l'unico
  /// progetto del piano free.
  static const bool tgramForceEnable = bool.fromEnvironment(
    'TGRAM_FORCE_ENABLE',
  );

  /// URL del questionario Google per segnalare errori o inviare suggerimenti.
  static const String feedbackUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLScKqaRKMwmwfi6Fq51-1z6SlZezeuB2q7kDyEr-BBDZwGocKQ/viewform';

  /// URL della repository GitHub del progetto.
  static const String githubUrl = 'https://github.com/davidetarsi/PackLog';

  /// URL pubblico della Privacy Policy. Mostrato come link nel checkbox di
  /// consenso in [LoginScreen] e obbligatorio per la scheda Play Store.
  static const String privacyPolicyUrl =
      'https://packlog.davidetarsi.com/privacy/';

  /// URL pubblico dei Termini di Servizio. Mostrato come link nel checkbox di
  /// consenso in [LoginScreen].
  static const String termsOfServiceUrl =
      'https://packlog.davidetarsi.com/termini/';

  /// URL pubblico del form di richiesta cancellazione account.
  ///
  /// Richiesto da Play Console nella sezione Data safety ("URL di
  /// cancellazione"): deve essere raggiungibile **senza login e senza account
  /// Google**, perché serve anche a chi ha già disinstallato l'app. In app la
  /// cancellazione avviene invece da Profilo → Elimina account, che è
  /// immediata (vedi edge function `hard-delete-account`).
  static const String accountDeletionUrl =
      'https://packlog.davidetarsi.com/cancellazione/';

  /// Versione corrente di Privacy Policy e Termini, registrata insieme al
  /// consenso dell'utente.
  ///
  /// Serve a sapere **cosa** è stato accettato: senza questo dato, quando i
  /// documenti cambiano non si può più distinguere chi ha accettato la
  /// versione vecchia da chi ha accettato quella nuova.
  ///
  /// Va incrementata a ogni modifica sostanziale dei documenti legali.
  static const String policyVersion = '2026-07-30';

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
    if (tgramApiKey.isEmpty || tgramApiKey == 'MISSING_TGRAM_API_KEY') {
      missing.add('TGRAM_API_KEY');
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'Errore di Build: variabili mancanti: ${missing.join(', ')}',
      );
    }
  }
}
