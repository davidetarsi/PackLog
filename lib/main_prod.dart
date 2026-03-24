/// Entry-point per il flavor **prod**.
///
/// Responsabilità unica (SRP): dichiarare l'ambiente e delegare
/// l'intera logica di avvio a [bootstrap].
///
/// Comando di esecuzione:
/// ```bash
/// flutter run --flavor prod -t lib/main_prod.dart
/// ```
///
/// Comando di build APK:
/// ```bash
/// flutter build apk --flavor prod -t lib/main_prod.dart
/// flutter build appbundle --flavor prod -t lib/main_prod.dart
/// ```
library;

import 'bootstrap.dart';

Future<void> main() async => bootstrap(Environment.prod);
