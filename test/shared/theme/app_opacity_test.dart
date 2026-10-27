import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

/// Rapporto di contrasto WCAG: (L1 + 0.05) / (L2 + 0.05), L1 la più chiara.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('contrasto della pillola scelta nel tema scuro', () {
    final cs = AppTheme.dark.colorScheme;
    // Come app_pill_tab.dart: testo nel tema scuro = primary, fondo = velo di
    // primary al livello della scelta sulla superficie.
    final background = Color.alphaBlend(
      cs.primary.withValues(alpha: AppOpacity.selected),
      cs.surface,
    );

    expect(_contrast(cs.primary, background), greaterThanOrEqualTo(4.5));
  });
}
