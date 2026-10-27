import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: `ListTile` e `Divider` si scrivono solo nei componenti del design
/// system. Il `(?<!...)` lascia fuori `DsDivider(`, `VerticalDivider(` e
/// `CheckboxListTile(`, che non sono i widget controllati qui.
void main() {
  final rawListTile = RegExp(r'(?<![A-Za-z0-9_])ListTile\(');
  final rawDivider = RegExp(r'(?<![A-Za-z0-9_])Divider\(');
  const allowedDirs = <String>['lib/shared/dev/'];

  List<String> offenders(RegExp raw, Set<String> allowed) {
    final found = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart') ||
          allowed.contains(path) ||
          allowedDirs.any(path.startsWith)) {
        continue;
      }
      if (raw.hasMatch(entity.readAsStringSync())) {
        found.add(path);
      }
    }
    found.sort();
    return found;
  }

  test('ListTile solo in ds_settings, universal_item_tile e create_sheet', () {
    const allowed = <String>{
      'lib/shared/widgets/ds_settings.dart',
      'lib/shared/widgets/universal_item_tile.dart',
      'lib/shared/widgets/create_sheet.dart',
    };

    expect(
      offenders(rawListTile, allowed),
      isEmpty,
      reason: 'ListTile( fuori dai componenti permessi in:',
    );
  });

  test('Divider solo in ds_divider.dart, usare DsDivider', () {
    const allowed = <String>{'lib/shared/widgets/ds_divider.dart'};

    expect(
      offenders(rawDivider, allowed),
      isEmpty,
      reason: 'Divider( fuori da DsDivider in:',
    );
  });
}
