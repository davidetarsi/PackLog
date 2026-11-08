import 'pack_trip_service.dart';

/// La chiave del messaggio per una valigia AI non riuscita: senza rete si
/// dice di controllare la connessione, ogni altro errore dice che il credito
/// non è stato scalato (il server lo restituisce se `pack-trip` fallisce).
String aiFailureMessageKey(Object error) => error is PackTripNetworkException
    ? 'trips.ai.failed_network'
    : 'trips.ai.failed_no_credit';
