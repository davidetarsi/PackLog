import 'package:flutter/material.dart';

/// Scala semantica del testo — 4 livelli (DS Fase 2 §2.1).
///
/// Regola: non usare onSurface.withValues(alpha: X) per il testo muted.
/// Usare invece questi getter che delegano al ColorScheme tema-aware.
///
/// | Livello    | Getter           | Uso tipico                                 |
/// |------------|------------------|--------------------------------------------|
/// | Primario   | textPrimary      | Titoli, body principale                    |
/// | Secondario | textSecondary    | Subtitle, info, metadata                   |
/// | Terziario  | textTertiary     | Caption, footnote, "x N altri", lineThrough|
/// | Disabilitato | textDisabled   | Hint, placeholder, disabled label           |
extension TextColors on BuildContext {
  /// Testo primario — titoli, body principale.
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;

  /// Testo secondario — subtitle, info, metadata.
  /// Usa onSurfaceVariant (calibrato per WCAG AA in entrambi i temi).
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;

  /// Testo terziario — caption, footnote, counter, testo barrato.
  /// Unico caso in cui sopravvive un alpha runtime (0.50).
  Color get textTertiary =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.50);

  /// Testo disabilitato / hint — standard Material 3.
  Color get textDisabled =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.38);
}

/// State layer standard Material 3 — 3 livelli (DS Fase 2 §2.2).
///
/// Uso: `color: context.stateHover(colorScheme.primary)`
extension StateColors on BuildContext {
  /// Hover / pressed — 8 % opacity.
  Color stateHover(Color base) => base.withValues(alpha: 0.08);

  /// Focus / selected — 12 % opacity.
  Color stateSelected(Color base) => base.withValues(alpha: 0.12);

  /// Dragged — 16 % opacity.
  Color stateDragged(Color base) => base.withValues(alpha: 0.16);
}
