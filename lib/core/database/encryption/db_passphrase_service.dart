import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'encryption_exceptions.dart';

/// Gestisce la passphrase del database SQLCipher: la genera al primo
/// accesso, la persiste in secure storage (Keychain/Keystore via
/// `flutter_secure_storage`), e la rilegge nelle sessioni successive.
///
/// **Forza della passphrase**: 32 byte random da `Random.secure()`
/// (256 bit di entropia), codificata in hex (64 char) per passarla via
/// `PRAGMA key = '<hex>'` di SQLCipher senza problemi di escaping.
///
/// **Vincolo critico**: la passphrase NON viene mai mostrata all'utente
/// né esportata. Se l'utente disinstalla l'app il secure storage viene
/// cancellato → il DB locale diventa irrecuperabile. È accettabile perché
/// i dati vivono anche su Supabase: dopo reinstall + login l'app rifa
/// fullPull e ricostruisce tutto.
class DbPassphraseService {
  static const String kStorageKey = 'stuff_tracker_db_key';
  static const int kPassphraseBytes = 32;

  final FlutterSecureStorage _secure;

  DbPassphraseService({FlutterSecureStorage? secure})
      : _secure = secure ?? _defaultStorage();

  static FlutterSecureStorage _defaultStorage() => const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  Future<String> getOrCreate() async {
    try {
      final existing = await _secure.read(key: kStorageKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final fresh = _generateHexPassphrase();
      await _secure.write(key: kStorageKey, value: fresh);
      return fresh;
    } on EncryptionException {
      rethrow;
    } catch (e, st) {
      throw PassphraseUnavailableException(
        'Cannot access secure storage for DB passphrase',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> exists() async {
    try {
      final value = await _secure.read(key: kStorageKey);
      return value != null && value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _generateHexPassphrase() {
    final rng = Random.secure();
    final bytes = Uint8List(kPassphraseBytes);
    for (var i = 0; i < kPassphraseBytes; i++) {
      bytes[i] = rng.nextInt(256);
    }
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }
}
