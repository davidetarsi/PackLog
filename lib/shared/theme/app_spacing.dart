import 'package:flutter/material.dart';

/// Classe per gestire spaziature e dimensioni responsive.
/// Usa questi valori invece di numeri magici per mantenere proporzioni consistenti.
class AppSpacing {
  // === Spaziature base ===
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // === Dimensioni icone base ===
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
  static const double iconHero = 64;

  // === Font size base ===
  static const double fontXs = 14;
  static const double fontSm = 16;
  static const double fontMd = 18;
  static const double fontLg = 20;
  static const double fontXl = 22;
  static const double fontTitle = 24;
  static const double fontHeading = 28;

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

/// Extension per calcolare valori responsive basati sulla larghezza dello schermo.
/// Mantiene le proporzioni degli elementi al variare delle dimensioni del dispositivo.
extension ResponsiveSpacing on BuildContext {
  /// Larghezza dello schermo
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Altezza dello schermo
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Fattore di scala basato sulla larghezza (1.0 per schermo da 375px)
  double get scaleFactor {
    const baseWidth = 375.0;
    const minScale = 0.85;
    const maxScale = 1.3;
    final scale = screenWidth / baseWidth;
    return scale.clamp(minScale, maxScale);
  }

  /// Fattore di scala per font (più conservativo)
  double get fontScaleFactor {
    const baseWidth = 375.0;
    const minScale = 0.9;
    const maxScale = 1.15;
    final scale = screenWidth / baseWidth;
    return scale.clamp(minScale, maxScale);
  }

  // === Spaziature responsive ===

  double get spacingXs => AppSpacing.xs * scaleFactor;
  double get spacingSm => AppSpacing.sm * scaleFactor;
  double get spacingMd => AppSpacing.md * scaleFactor;
  double get spacingLg => AppSpacing.lg * scaleFactor;
  double get spacingXl => AppSpacing.xl * scaleFactor;

  // === Icone responsive ===

  double get iconSizeSm => AppSpacing.iconSm * scaleFactor;
  double get iconSizeMd => AppSpacing.iconMd * scaleFactor;
  double get iconSizeLg => AppSpacing.iconLg * scaleFactor;
  double get iconSizeXl => AppSpacing.iconXl * scaleFactor;
  double get iconSizeHero => AppSpacing.iconHero * scaleFactor;

  // === Font responsive ===

  double get fontSizeXs => AppSpacing.fontXs * fontScaleFactor;
  double get fontSizeSm => AppSpacing.fontSm * fontScaleFactor;
  double get fontSizeMd => AppSpacing.fontMd * fontScaleFactor;
  double get fontSizeLg => AppSpacing.fontLg * fontScaleFactor;
  double get fontSizeXl => AppSpacing.fontXl * fontScaleFactor;
  double get fontSizeTitle => AppSpacing.fontTitle * fontScaleFactor;
  double get fontSizeHeading => AppSpacing.fontHeading * fontScaleFactor;

  // === Padding responsive ===

  EdgeInsets get responsiveScreenPadding => EdgeInsets.all(spacingMd);

  EdgeInsets get responsiveCardPadding => EdgeInsets.all(spacingSm);

  EdgeInsets responsiveSymmetricPadding({
    double horizontal = 0,
    double vertical = 0,
  }) => EdgeInsets.symmetric(
    horizontal: horizontal * scaleFactor,
    vertical: vertical * scaleFactor,
  );

  EdgeInsets responsivePadding({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => EdgeInsets.only(
    left: left * scaleFactor,
    top: top * scaleFactor,
    right: right * scaleFactor,
    bottom: bottom * scaleFactor,
  );

  // === SizedBox responsive ===

  SizedBox responsiveGap(double height) =>
      SizedBox(height: height * scaleFactor);
  SizedBox responsiveHGap(double width) => SizedBox(width: width * scaleFactor);

  // === BorderRadius responsive ===

  BorderRadius responsiveBorderRadius(double radius) =>
      BorderRadius.circular(radius * scaleFactor);

  // === Utility per valori arbitrari ===

  /// Scala un valore arbitrario in base alla larghezza dello schermo
  double responsive(double value) => value * scaleFactor;

  /// Scala un valore arbitrario per i font
  double responsiveFont(double value) => value * fontScaleFactor;
}

/// Widget helper per creare gap verticali responsive
class ResponsiveGap extends StatelessWidget {
  final double height;

  const ResponsiveGap(this.height, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: context.responsive(height));
  }
}

/// Widget helper per creare gap orizzontali responsive
class ResponsiveHGap extends StatelessWidget {
  final double width;

  const ResponsiveHGap(this.width, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: context.responsive(width));
  }
}
