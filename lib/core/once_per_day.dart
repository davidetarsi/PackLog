import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Il giorno come testo (anno-mese-giorno), nel fuso del dispositivo.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Vero se [e] dice che la richiesta non è arrivata al server (rete assente,
/// tempo scaduto, connessione rifiutata): in quel caso il controllo del giorno
/// non è avvenuto.
bool isNetworkFailure(Object e) =>
    e is SocketException ||
    e is TimeoutException ||
    e is HandshakeException ||
    e is http.ClientException;

final Set<String> _inCorso = {};

/// Esegue [action] al massimo una volta al giorno (decisione di Davide del 31
/// ottobre: letture rare), ricordando il giorno in SharedPreferences sotto
/// [key]. Una sola logica per il catalogo e per il dizionario del Rapid Fire.
///
/// Il giorno si segna solo dopo una risposta del server, anche d'errore, e solo
/// con l'utente autenticato (le tabelle si leggono da `authenticated`):
/// - senza sessione ([hasSession] falso) non si fa nulla e il giorno resta libero;
/// - con un'eccezione di rete ([isNetworkFailure]) il giorno resta libero, e
///   l'apertura offline non consuma il controllo;
/// - con qualunque altra eccezione il server ha risposto: il giorno si segna.
///
/// Restituisce il risultato di [action], o null se non ha girato. Le eccezioni
/// di [action] si rilanciano, a chi chiama il compito di loggarle. Due chiamate
/// insieme con la stessa [key] fanno girare [action] una volta sola.
Future<T?> runOncePerDay<T>({
  required String key,
  required bool hasSession,
  required Future<T> Function() action,
  DateTime Function()? now,
}) async {
  if (!hasSession) return null;
  final prefs = await SharedPreferences.getInstance();
  final oggi = dayKey((now ?? DateTime.now)());
  if (prefs.getString(key) == oggi) return null;
  if (!_inCorso.add(key)) return null;
  try {
    final risultato = await action();
    await prefs.setString(key, oggi);
    return risultato;
  } catch (e) {
    if (!isNetworkFailure(e)) await prefs.setString(key, oggi);
    rethrow;
  } finally {
    _inCorso.remove(key);
  }
}
