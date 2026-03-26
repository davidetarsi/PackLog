/// Alias di convenienza per `flutter run` senza specificare `-t`.
///
/// Questo file esiste esclusivamente per mantenere la compatibilità con
/// gli strumenti che assumono `lib/main.dart` come entry-point di default
/// (IDE, CI pipeline legacy, script di build non aggiornati).
///
/// ⚠️  Per build ufficiali usare sempre l'entry-point esplicito del flavor:
/// ```bash
/// # Sviluppo
/// flutter run --flavor dev -t lib/main_dev.dart
///
/// # Produzione
/// flutter build apk --flavor prod -t lib/main_prod.dart
/// flutter build appbundle --flavor prod -t lib/main_prod.dart
/// ```
library;

import 'bootstrap.dart';

/// Avvia l'app in modalità [Environment.dev] per convenienza locale.
///
/// Non usare per build di produzione.
Future<void> main() async => bootstrap(Environment.dev);
