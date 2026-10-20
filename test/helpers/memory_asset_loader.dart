import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Traduzioni lette una volta dal disco e servite in memoria: niente I/O
/// asincrono sugli asset dentro il test, che lascerebbe EasyLocalization in
/// caricamento e il widget non costruito.
class MemoryAssetLoader extends AssetLoader {
  const MemoryAssetLoader(this.translations);

  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations[locale.toString()] ?? translations['en_US']!;
}

/// Dizionari it-IT e en-US letti da `assets/translations`.
Map<String, Map<String, dynamic>> readAppTranslations() => {
  'it_IT':
      jsonDecode(File('assets/translations/it-IT.json').readAsStringSync())
          as Map<String, dynamic>,
  'en_US':
      jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
          as Map<String, dynamic>,
};
