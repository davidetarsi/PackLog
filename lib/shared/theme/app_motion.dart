import 'package:flutter/animation.dart';

/// Durate e curve delle animazioni dell'app: un solo valore per ogni ruolo.
abstract final class AppMotion {
  /// Stato di un controllo: pillola, icona scelta, categoria.
  static const Duration fast = Duration(milliseconds: 150);

  /// Cambio di contenuto: barra, pila, campo.
  static const Duration medium = Duration(milliseconds: 200);

  /// Movimento di pagina: scroll, onboarding.
  static const Duration slow = Duration(milliseconds: 300);

  /// Transizione generica tra due stati.
  static const Curve standard = Curves.easeInOut;

  /// Elemento che entra e si posa.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Andamento costante: la sfocatura del bordo in fondo, che cresce in modo
  /// uniforme verso il bordo dello schermo.
  static const Curve linear = Curves.linear;
}
