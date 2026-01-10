import 'package:flutter/material.dart';

/// Spaziature consistenti per tutta l'app.
/// Usa questi valori invece di numeri magici.
abstract class AppSpacing {
  // === Valori base ===
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // === Padding predefiniti ===

  /// Padding standard per le schermate
  static const EdgeInsets screenPadding = EdgeInsets.all(md);

  /// Padding per le card
  static const EdgeInsets cardPadding = EdgeInsets.all(sm);

  /// Padding per gli elementi di una lista
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  /// Padding per i contenuti di un bottom sheet
  static const EdgeInsets sheetPadding = EdgeInsets.all(md);

  // === Gap verticali ===

  /// Gap piccolo tra elementi correlati
  static const SizedBox gapSm = SizedBox(height: sm);

  /// Gap medio tra sezioni
  static const SizedBox gapMd = SizedBox(height: md);

  /// Gap grande tra gruppi di contenuto
  static const SizedBox gapLg = SizedBox(height: lg);

  // === Gap orizzontali ===

  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
}

