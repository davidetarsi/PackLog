/// Entry-point per il flavor **dev**.
///
/// Responsabilità unica (SRP): dichiarare l'ambiente e delegare
/// l'intera logica di avvio a [bootstrap].
///
/// Comando di esecuzione:
/// ```bash
/// flutter run --flavor dev -t lib/main_dev.dart
/// ```
///
/// Comando di build APK:
/// ```bash
/// flutter build apk --flavor dev -t lib/main_dev.dart
/// ```
library;

import 'bootstrap.dart';

Future<void> main() async => bootstrap(Environment.dev);
