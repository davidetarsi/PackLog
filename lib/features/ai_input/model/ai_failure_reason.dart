import 'clothing_analysis_exception.dart';

/// Motivo per cui un'analisi AI è fallita, in termini comprensibili all'utente.
///
/// Esiste per separare due cose che prima erano la stessa: il messaggio
/// tecnico dell'eccezione (utile a Sentry e ai log) e ciò che si mostra a
/// schermo. Prima il primo finiva direttamente nella UI, portandosi dietro il
/// nome della classe d'errore e l'URI del proxy Supabase.
///
/// Stesso pattern di `AuthFailureReason` in `core/auth/auth_exceptions.dart`.
enum AiFailureReason {
  /// La richiesta non ha raggiunto il server: rete assente, timeout, DNS.
  network,

  /// La sessione non è valida: serve rientrare.
  notAuthenticated,

  /// Quota di scansioni AI esaurita. Non è un errore: è un limite.
  limitReached,

  /// Il servizio ha risposto con un errore, o la risposta era illeggibile.
  serviceError,

  /// Tutto il resto.
  unknown;

  /// Chiave di traduzione del messaggio da mostrare.
  String get messageKey => switch (this) {
    AiFailureReason.network => 'ai_import.error_network',
    AiFailureReason.notAuthenticated => 'ai_import.error_not_authenticated',
    AiFailureReason.limitReached => 'ai_import.limit_reached',
    AiFailureReason.serviceError => 'ai_import.error_service',
    AiFailureReason.unknown => 'ai_import.error_unknown',
  };

  /// Se riprovare la stessa operazione può ragionevolmente riuscire.
  ///
  /// Il limite di quota e la sessione scaduta non si risolvono riprovando:
  /// mostrare un pulsante "Riprova" lì sarebbe una promessa falsa.
  bool get isRetryable => switch (this) {
    AiFailureReason.network => true,
    AiFailureReason.serviceError => true,
    AiFailureReason.unknown => true,
    AiFailureReason.notAuthenticated => false,
    AiFailureReason.limitReached => false,
  };
}

/// Traduce un errore qualsiasi nel motivo corrispondente.
///
/// Lo `switch` sulla sealed class è esaustivo: aggiungendo una nuova
/// `ClothingAnalysisException` il compilatore obbliga a decidere qui che
/// faccia mostrare all'utente, invece di lasciarla cadere in `unknown`.
AiFailureReason aiFailureReasonFrom(Object error) => switch (error) {
  AnalysisNetworkException() => AiFailureReason.network,
  AnalysisNotAuthenticatedException() => AiFailureReason.notAuthenticated,
  GptLimitExceededException() => AiFailureReason.limitReached,
  VisionAnalysisException() => AiFailureReason.serviceError,
  BackgroundRemovalException() => AiFailureReason.serviceError,
  ResponseParsingException() => AiFailureReason.serviceError,
  _ => AiFailureReason.unknown,
};
