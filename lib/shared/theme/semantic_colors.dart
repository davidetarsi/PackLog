import 'package:flutter/material.dart';

/// Testo terziario (DS Fase 2 §2.1): caption, footnote, counter, testo barrato.
///
/// Regola: non usare onSurface.withValues(alpha: X) per il testo muted.
/// Usare invece questo getter, che è tema-aware.
extension TextColors on BuildContext {
  /// Testo terziario — caption, footnote, counter, testo barrato.
  /// Unico caso in cui sopravvive un alpha runtime (0.50).
  Color get textTertiary =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.50);
}
