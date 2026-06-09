import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

File _fakeFile([String name = 'test.png']) {
  return File('${Directory.systemTemp.path}/$name')
    ..writeAsBytesSync(Uint8List.fromList([137, 80, 78, 71]));
}

ClothingAnalysisResult _result({String name = 'T-Shirt'}) =>
    ClothingAnalysisResult(
      name: name,
      category: 'Upper Body',
      subCategory: 'T-Shirt',
      baseColor: 'Bianco',
      pattern: 'Solid',
      coverage: 'Short-sleeve',
      fit: 'Regular',
      warmth: 2,
      formality: 'Casual',
      activityTags: const ['Everyday'],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── PhotoGroup ──────────────────────────────────────────────────────────────

  group('PhotoGroup', () {
    test('two instances sharing the same File and equal results are equal', () {
      final file = _fakeFile();
      final results = [_result()];
      final g1 = PhotoGroup(photo: file, results: results);
      final g2 = PhotoGroup(photo: file, results: results);
      expect(g1, g2);
    });

    test('instances with different results are not equal', () {
      final file = _fakeFile();
      final g1 = PhotoGroup(photo: file, results: [_result(name: 'T-Shirt')]);
      final g2 = PhotoGroup(photo: file, results: [_result(name: 'Jeans')]);
      expect(g1, isNot(g2));
    });

    test('copyWith changes results, leaves photo unchanged', () {
      final file = _fakeFile();
      final g = PhotoGroup(photo: file, results: [_result(name: 'T-Shirt')]);
      final newResults = [_result(name: 'Jeans')];
      final copy = g.copyWith(results: newResults);

      expect(copy.results.first.name, 'Jeans');
      expect(copy.photo, same(file));
    });

    test('copyWith changes photo, leaves results unchanged', () {
      final file1 = _fakeFile('a.png');
      final file2 = _fakeFile('b.png');
      final g = PhotoGroup(photo: file1, results: [_result()]);
      final copy = g.copyWith(photo: file2);

      expect(copy.photo, same(file2));
      expect(copy.results, g.results);
    });
  });

  // ── AiImportState ────────────────────────────────────────────────────────────

  group('AiImportState', () {
    test('default constructor produces empty state', () {
      const s = AiImportState();
      expect(s.photoGroups, isEmpty);
      expect(s.isLoading, isFalse);
      expect(s.processingIndex, 0);
      expect(s.totalImages, 0);
      expect(s.errorMessage, isNull);
      expect(s.selectedHouseId, isNull);
    });

    test('two default instances are equal', () {
      expect(const AiImportState(), const AiImportState());
    });

    test('copyWith replaces only the specified fields', () {
      const s = AiImportState();
      final s2 = s.copyWith(isLoading: true, totalImages: 3);
      expect(s2.isLoading, isTrue);
      expect(s2.totalImages, 3);
      expect(s2.photoGroups, isEmpty);
      expect(s2.selectedHouseId, isNull);
    });

    test('copyWith with selectedHouseId updates only that field', () {
      const s = AiImportState();
      final s2 = s.copyWith(selectedHouseId: 'house-1');
      expect(s2.selectedHouseId, 'house-1');
      expect(s2.isLoading, isFalse);
    });
  });
}
