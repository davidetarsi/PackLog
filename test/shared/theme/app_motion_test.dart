import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_motion.dart';

/// Guardia: fuori da `app_motion.dart` e dalla vetrina dev (`lib/shared/dev/`)
/// nessuna curva scritta a mano. Le curve stanno in `AppMotion`.
List<String> _curveOffenders() {
  const excluded = <String>['lib/shared/dev/'];
  const allowedFile = 'lib/shared/theme/app_motion.dart';
  final out = <String>[];

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path == allowedFile ||
        excluded.any(path.startsWith)) {
      continue;
    }
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('Curves.')) {
        out.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return out;
}

void main() {
  test('valori', () {
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.medium, const Duration(milliseconds: 200));
    expect(AppMotion.slow, const Duration(milliseconds: 300));
    expect(AppMotion.standard, Curves.easeInOut);
    expect(AppMotion.emphasized, Curves.easeOutCubic);
  });

  test('nessuna curva fuori da AppMotion', () {
    final offenders = _curveOffenders();
    expect(
      offenders,
      isEmpty,
      reason:
          'Curves.* fuori da AppMotion (usa AppMotion.standard / emphasized):\n'
          '${offenders.join('\n')}',
    );
  });
}
