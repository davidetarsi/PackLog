import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';

/// Guardie: fuori dal tema (`lib/shared/theme/`) e dalla vetrina dev
/// (`lib/shared/dev/`) niente raggi o icone con un numero scritto a mano.
/// Le misure vanno prese dai token di `AppSpacing` / `AppConstants`.
List<String> _offenders(
  RegExp pattern, {
  List<String> excluded = const ['lib/shared/theme/', 'lib/shared/dev/'],
}) {
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
  test('token nuovi', () {
    expect(AppSpacing.xxs, 2);
    expect(AppSpacing.smPlus, 12);
    expect(AppSpacing.iconXs, 12);
    expect(AppSpacing.iconDisplay, 80);
    expect(AppConstants.smallBorderRadius, 4);
    expect(AppConstants.hairlineBorderWidth, 1);
    expect(AppConstants.selectedBorderWidth, 1.5);
  });

  test('nessun raggio numerico fuori dal tema', () {
    final offenders = _offenders(RegExp(r'circular\(\d'));
    expect(
      offenders,
      isEmpty,
      reason:
          'BorderRadius.circular(numero) fuori da AppConstants:\n'
          '${offenders.join('\n')}',
    );
  });

  test('nessuna icona con dimensione numerica', () {
    final offenders = _offenders(RegExp(r'size: \d'));
    expect(
      offenders,
      isEmpty,
      reason:
          'Icona con size numerico fuori dai token di AppSpacing:\n'
          '${offenders.join('\n')}',
    );
  });

  test('app_theme.dart senza numeri di misura', () {
    // Il tema è la fonte dei valori: spazi, raggi, icone e bordi passano dai
    // token. Qui il file si legge da solo, perché la guardia generale esclude
    // proprio lib/shared/theme/.
    final pattern = RegExp(
      r'(width|horizontal|vertical|bottom|top|IconSize|stateSpacing\w*): \d|circular\(\d',
    );
    final lines = File('lib/shared/theme/app_theme.dart').readAsLinesSync();
    final offenders = <String>[
      for (var i = 0; i < lines.length; i++)
        if (pattern.hasMatch(lines[i])) '${i + 1}: ${lines[i].trim()}',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Numeri di misura scritti a mano in app_theme.dart:\n'
          '${offenders.join('\n')}',
    );
  });

  test('nessun Card fuori dal tema', () {
    // Lookbehind: DsCard( o SkeletonCard( non sono il widget Material.
    final offenders = _offenders(
      RegExp(r'(?<![A-Za-z0-9_])Card\('),
      excluded: const ['lib/shared/dev/'],
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Card( in lib/ (la riga dell\'oggetto è piatta, il tema non ha '
          'cardTheme):\n'
          '${offenders.join('\n')}',
    );
  });
}
