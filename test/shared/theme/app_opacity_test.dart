import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_colors.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

/// Rapporto di contrasto WCAG: (L1 + 0.05) / (L2 + 0.05), L1 la più chiara.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Guardia: fuori dal tema (`lib/shared/theme/`) e dalla vetrina dev
/// (`lib/shared/dev/`) niente alpha scritto a mano in `withValues`.
/// I valori stanno in `AppOpacity`, i colori fissi in `AppColorsExtension`.
List<String> _alphaOffenders() {
  final pattern = RegExp(r'withValues\(alpha: \d');
  const excluded = <String>['lib/shared/theme/', 'lib/shared/dev/'];
  final out = <String>[];

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        excluded.any(path.startsWith)) {
      continue;
    }
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        out.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return out;
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

  test('valori', () {
    expect(AppOpacity.selected, 0.18);
    expect(AppOpacity.disabled, 0.38);
    expect(AppOpacity.pressed, 0.08);
    expect(AppOpacity.shadow, 0.12);
    expect(AppOpacity.mutedBorder, 0.5);
    expect(AppOpacity.navGlass, 0.78);
    expect(AppOpacity.ctaScrim, 0.72);
    expect(AppOpacity.textSelection, 0.24);
  });

  test('nessun alpha numerico fuori dal tema', () {
    final offenders = _alphaOffenders();
    expect(
      offenders,
      isEmpty,
      reason:
          'withValues(alpha: numero) fuori da AppOpacity / AppColorsExtension:\n'
          '${offenders.join('\n')}',
    );
  });

  test('tourScrim è nero in chiaro e in scuro', () {
    expect(AppColorsExtension.light.tourScrim, Colors.black);
    expect(AppColorsExtension.dark.tourScrim, Colors.black);
  });
}
