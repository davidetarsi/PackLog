import 'dart:io';

import 'package:flutter/services.dart';

/// Carica i font reali nel motore di test.
///
/// `flutter test` di default disegna ogni glifo con il font "Ahem" (quadratini
/// neri) e non conosce né Roboto né MaterialIcons: uno screenshot così non
/// serve a giudicare la UI. I file stanno nella cache dell'SDK Flutter
/// (`bin/cache/artifacts/material_fonts`), la stessa da cui l'app li prende su
/// Android, quindi non serve aggiungerli agli asset del progetto.
///
/// Il tema dichiara `fontFamily: 'sans-serif'` (alias Android di Roboto):
/// registriamo Roboto sotto entrambi i nomi.
Future<void> loadRealFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? _flutterRootFromExecutable();
  final dir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    throw StateError('Font Material non trovati in ${dir.path}');
  }

  final roboto = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'/Roboto-[A-Za-z]+\.ttf$').hasMatch(f.path))
      .toList();

  for (final family in ['Roboto', 'sans-serif']) {
    final loader = FontLoader(family);
    for (final file in roboto) {
      loader.addFont(_bytes(file));
    }
    await loader.load();
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(_bytes(File('${dir.path}/MaterialIcons-Regular.otf')));
  await icons.load();
}

Future<ByteData> _bytes(File file) async =>
    ByteData.sublistView(await file.readAsBytes());

String _flutterRootFromExecutable() {
  // .../flutter/bin/cache/dart-sdk/bin/dart → .../flutter
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/bin/flutter').existsSync()) return dir.path;
    dir = dir.parent;
  }
  throw StateError('FLUTTER_ROOT non determinabile');
}
