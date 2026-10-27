import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: il peso e lo stile del testo passano dal tema (`lib/shared/theme/`).
/// Ogni file di `lib/` è controllato, tranne i generati e `lib/shared/dev/`.
const _exempt = {
  // Fino al Task 6, che riscrive il menu.
  'lib/shared/widgets/entity_context_menu.dart',
};

List<String> _offenders(String needle) {
  final offenders = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.startsWith('lib/shared/theme/') ||
        path.startsWith('lib/shared/dev/') ||
        _exempt.contains(path)) {
      continue;
    }
    if (entity.readAsStringSync().contains(needle)) {
      offenders.add(path);
    }
  }
  offenders.sort();
  return offenders;
}

void main() {
  test('nessun FontWeight fuori dal tema', () {
    expect(
      _offenders('FontWeight.'),
      isEmpty,
      reason: 'FontWeight fuori da lib/shared/theme/ in:',
    );
  });

  test('nessun TextStyle costruito a mano fuori dal tema', () {
    expect(
      _offenders('TextStyle('),
      isEmpty,
      reason: 'TextStyle( fuori da lib/shared/theme/ in:',
    );
  });
}
