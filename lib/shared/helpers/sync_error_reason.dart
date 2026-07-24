/// Mappa una stringa di errore grezza (già serializzata via `e.toString()`
/// da [SyncService], vedi `lastSyncError` in [SyncDaoMixin.incrementSyncRetry])
/// in una chiave i18n user-friendly.
///
/// NON riusa `exceptionMessage()` (in `exception_message.dart`): quella
/// funzione fa pattern-matching su *tipi* di eccezione Dart, ma qui il tipo è
/// già perso — `lastSyncError` è testo persistito, non un'istanza di
/// Exception. Questo mapper fa quindi pattern-matching euristico su
/// sottostringhe note, con fallback generico per tutto il resto: mai
/// mostrare il testo tecnico grezzo all'utente medio.
String syncErrorReasonKey(String? rawError) {
  if (rawError == null || rawError.isEmpty) {
    return 'profile.sync_reason_unknown';
  }

  final lower = rawError.toLowerCase();

  const networkMarkers = [
    'socketexception',
    'timeoutexception',
    'connection timed out',
    'failed host lookup',
    'network is unreachable',
    'connection refused',
  ];
  if (networkMarkers.any(lower.contains)) {
    return 'profile.sync_reason_network';
  }

  const serverMarkers = ['postgrestexception', 'code: 500', 'code: 502', 'code: 503'];
  if (serverMarkers.any(lower.contains)) {
    return 'profile.sync_reason_server';
  }

  return 'profile.sync_reason_unknown';
}
