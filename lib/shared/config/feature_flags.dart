import 'package:flutter/foundation.dart';

/// Feature flag per la schermata AI Sandbox (beta).
///
/// - In debug/dev: `true` per consentire ai beta tester di accedere.
/// - Sovrascrivibile via `--dart-define=ENABLE_AI_SANDBOX=false` per build
///   di produzione destinate al pubblico generico.
///
/// Uso nel router:
/// ```dart
/// if (!kEnableAiSandbox) return _ErrorScreen(message: '...');
/// ```
const bool kEnableAiSandbox = bool.fromEnvironment(
  'ENABLE_AI_SANDBOX',
  defaultValue: kDebugMode,
);
