import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'analytics_session.g.dart';

/// UUID della sessione analytics corrente, generato **una volta per avvio**
/// dell'app.
///
/// tgram-analytics richiede un `sessionId` esplicito su ogni evento (a
/// differenza di Amplitude, che gestisce le sessioni internamente). Qui la
/// semantica scelta è "una sessione = un cold start": il valore vive finché
/// vive il process e non viene persistito su disco.
///
/// **Perché non un id persistente**: un UUID salvato su disco sopravvivrebbe
/// ai riavvii, diventando di fatto un identificatore stabile del dispositivo —
/// con le implicazioni che ne derivano per la scheda Data Safety del Play
/// Store. Restando in memoria, l'unico legame con l'utente reale è quello
/// esplicito creato al login (vedi [AppAnalyticsService.identifyUser], che
/// chiama `TGA.identify` con lo userId Supabase).
///
/// `keepAlive` è necessario: se il provider venisse smaltito e ricostruito,
/// gli eventi della stessa esecuzione finirebbero divisi tra sessioni diverse.
@Riverpod(keepAlive: true)
String analyticsSessionId(Ref ref) => const Uuid().v4();
