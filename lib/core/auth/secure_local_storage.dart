import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persistenza della sessione Supabase su storage cifrato a livello OS.
///
/// - **Android**: `EncryptedSharedPreferences` backed by Android Keystore
///   (AES-256-GCM con chiave derivata in Keystore).
/// - **iOS**: Keychain con
///   `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` → il token NON viene
///   incluso negli iCloud backup e non è leggibile prima del primo sblocco
///   post-boot.
///
/// Sostituisce il default di `supabase_flutter` (`SharedPreferencesLocalStorage`),
/// che salva il refresh token in chiaro nelle prefs di sistema (estraibile su
/// device rooted/jailbroken o via backup ADB).
///
/// ## Migrazione trasparente
/// All'`initialize()`, se troviamo una sessione nelle vecchie
/// SharedPreferences (utente già loggato con la versione precedente
/// dell'app), la copiamo in secure storage e la cancelliamo da SP. L'utente
/// non subisce relogin.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({
    required this.persistSessionKey,
    FlutterSecureStorage? secure,
  }) : _secure = secure ?? _defaultSecureStorage();

  /// Stessa chiave usata da `SharedPreferencesLocalStorage` di default
  /// (`sb-<project-ref>-auth-token`). Manteniamo il nome per riusare la
  /// logica di migrazione e tornare facilmente al default in test.
  final String persistSessionKey;

  final FlutterSecureStorage _secure;

  /// Opzioni piattaforma sensate per dati di autenticazione:
  /// - Android: storage cifrato by-default in flutter_secure_storage 10.x
  ///   (cipher AES-GCM con chiave derivata in Keystore). La proprietà
  ///   esplicita `encryptedSharedPreferences` è deprecated → ignorata.
  /// - iOS: accessibilità solo dopo primo unlock, *this device only* → no
  ///   iCloud backup del token.
  static FlutterSecureStorage _defaultSecureStorage() =>
      const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  @override
  Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _migrateFromSharedPreferencesIfNeeded();
  }

  Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    try {
      // Already migrated? Niente da fare.
      final existing = await _secure.read(key: persistSessionKey);
      if (existing != null && existing.isNotEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null || legacy.isEmpty) return;

      await _secure.write(key: persistSessionKey, value: legacy);
      await prefs.remove(persistSessionKey);
      debugPrint(
        '[SecureLocalStorage] Migrated legacy session from SharedPreferences',
      );
    } catch (e) {
      // Migrazione best-effort: se fallisce, l'utente farà relogin — meglio
      // di un crash al boot. Logghiamo per visibilità.
      debugPrint('[SecureLocalStorage] Legacy migration failed: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await _secure.read(key: persistSessionKey);
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _secure.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _secure.delete(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(key: persistSessionKey, value: persistSessionString);
}
