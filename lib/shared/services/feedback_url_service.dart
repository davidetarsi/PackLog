import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';

/// Risultato della costruzione dell'URL di feedback.
///
/// Separare il risultato in un value object rende il metodo testabile
/// senza dipendere dal browser o da `BuildContext`.
class FeedbackUrlResult {
  /// URL completo con query parameters pre-compilati.
  final Uri uri;

  /// Versione app usata per pre-compilare il form (es. "1.2.3+4").
  final String appVersion;

  /// Sistema operativo rilevato (es. "android", "ios").
  final String os;

  FeedbackUrlResult({
    required this.uri,
    required this.appVersion,
    required this.os,
  });
}

/// Tipo del factory di [PackageInfo] iniettabile.
///
/// In produzione usa [PackageInfo.fromPlatform]; nei test viene sostituito
/// con una funzione che ritorna dati stub senza richiedere canali nativi.
typedef PackageInfoFactory = Future<PackageInfo> Function();

/// Servizio responsabile della costruzione dell'URL del Google Form di feedback
/// con pre-compilazione (Context Injection) dei campi OS e versione app.
///
/// ## Perché una classe separata?
///
/// Seguendo il principio **Single Responsibility** (SOLID), la logica di
/// costruzione dell'URL è isolata dallo screen che la usa. Questo permette:
/// - Test unitari puri senza dipendenze dal widget tree di Flutter.
/// - Sostituzione del provider `PackageInfo` nei test tramite DI.
/// - Riuso da qualsiasi punto dell'app senza duplicazione.
///
/// ## Dependency Injection del PackageInfo
///
/// Il parametro `packageInfoFactory` segue il principio **Dependency Inversion**:
/// il servizio dipende dall'astrazione (una funzione `async → PackageInfo`),
/// non dall'implementazione concreta ([PackageInfo.fromPlatform]).
/// In test, si inietta uno stub che non richiede canali nativi.
///
/// ## Come ottenere gli entry ID del tuo Google Form
///
/// 1. Apri il tuo Google Form in modalità risposta.
/// 2. Fai click destro → "Ispeziona elemento" su un campo.
/// 3. Cerca l'attributo `name` dell'input: sarà `entry.XXXXXXX`.
/// 4. Sostituisci [_osEntryId] e [_appVersionEntryId] con quei valori.
class FeedbackUrlService {
  /// Factory per ottenere [PackageInfo]. Di default usa [PackageInfo.fromPlatform].
  /// Iniettabile in test per evitare [MissingPluginException] su VM pura.
  final PackageInfoFactory _packageInfoFactory;

  FeedbackUrlService({PackageInfoFactory? packageInfoFactory})
      : _packageInfoFactory = packageInfoFactory ?? PackageInfo.fromPlatform;

  /// ID del campo "Sistema Operativo" nel Google Form.
  ///
  /// ⚠️  SOSTITUISCI con il valore reale del tuo form (es. `'entry.123456789'`).
  static const String _osEntryId = 'entry.833472047';

  /// ID del campo "Versione App" nel Google Form.
  ///
  /// ⚠️  SOSTITUISCI con il valore reale del tuo form (es. `'entry.987654321'`).
  static const String _appVersionEntryId = 'entry.1667459730';

  /// Costruisce l'[Uri] del form di feedback pre-compilato con contesto tecnico.
  ///
  /// Usa [_packageInfoFactory] per leggere la versione app e
  /// [Platform.operatingSystem] per il SO corrente.
  ///
  /// [Uri.replace] aggiunge i `queryParameters` con encoding automatico,
  /// garantendo che eventuali caratteri speciali (spazi, "+") siano correttamente
  /// percent-encoded nell'URL finale.
  ///
  /// Throws: Può lanciare eccezioni se [_packageInfoFactory] fallisce.
  /// Il chiamante ([_openFeedbackForm]) deve catturarle.
  Future<FeedbackUrlResult> build() async {
    final info = await _packageInfoFactory();
    final appVersion = '${info.version}+${info.buildNumber}';
    final os = Platform.operatingSystem;

    final uri = Uri.parse(AppConfig.feedbackUrl).replace(
      queryParameters: {
        'usp':'pp_url',
        _osEntryId: os,
        _appVersionEntryId: appVersion,
      },
    );

    return FeedbackUrlResult(uri: uri, appVersion: appVersion, os: os);
  }
}
