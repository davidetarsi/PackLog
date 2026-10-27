import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';

/// Guardie: fuori dal tema (`lib/shared/theme/`) e dalla vetrina dev
/// (`lib/shared/dev/`) niente raggi o icone con un numero scritto a mano.
/// Le misure vanno prese dai token di `AppSpacing` / `AppConstants`.
List<String> _offenders(RegExp pattern) {
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
}
