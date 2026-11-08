import 'pack_trip_service.dart';

/// La chiave del messaggio per una valigia AI non riuscita. Senza rete si
/// dice di controllare la connessione. "Nessun credito scalato" solo per gli
/// errori del server (il server lo restituisce se `pack-trip` fallisce). Ogni
/// altro errore (per esempio il salvataggio dopo una risposta riuscita, che il
/// credito l'ha già consumato) dice solo che la valigia non è stata salvata.
String aiFailureMessageKey(Object error) => switch (error) {
  PackTripNetworkException() => 'trips.ai.failed_network',
  PackTripException() ||
  PackTripCreditsException() ||
  PackTripEmptyWardrobeException() ||
  PackTripWardrobeTooLargeException() => 'trips.ai.failed_no_credit',
  _ => 'trips.ai.failed_save',
};
