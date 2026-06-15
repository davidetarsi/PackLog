import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/sync/supabase_repository.dart';

void main() {
  group('SupabaseRepository.paginatedFetch', () {
    test('stops when a page returns fewer rows than pageSize', () async {
      final pageCalls = <(int, int)>[];

      Future<List<Map<String, dynamic>>> fetchPage(int from, int to) async {
        pageCalls.add((from, to));
        // Simulate 5 total rows with pageSize=2 → pages: [0..1], [2..3], [4..4].
        const total = 5;
        if (from >= total) return const [];
        final last = (to >= total - 1) ? total - 1 : to;
        return [
          for (var i = from; i <= last; i++) {'id': '$i'},
        ];
      }

      final result = await SupabaseRepository.paginatedFetch(
        fetchPage: fetchPage,
        pageSize: 2,
      );

      expect(result, hasLength(5));
      expect(result.map((r) => r['id']), equals(['0', '1', '2', '3', '4']));
      // Page calls: (0,1) → 2 rows (full), (2,3) → 2 rows (full),
      // (4,5) → 1 row (short, stop).
      expect(pageCalls, equals([(0, 1), (2, 3), (4, 5)]));
    });

    test('returns empty list when the first page is empty', () async {
      Future<List<Map<String, dynamic>>> fetchPage(int from, int to) async {
        return const [];
      }

      final result = await SupabaseRepository.paginatedFetch(
        fetchPage: fetchPage,
        pageSize: 1000,
      );

      expect(result, isEmpty);
    });

    test('handles dataset exactly divisible by pageSize without infinite loop', () async {
      final pageCalls = <(int, int)>[];

      Future<List<Map<String, dynamic>>> fetchPage(int from, int to) async {
        pageCalls.add((from, to));
        // 4 total rows, pageSize=2 → exactly 2 full pages, then 1 empty.
        const total = 4;
        if (from >= total) return const [];
        final last = (to >= total - 1) ? total - 1 : to;
        return [
          for (var i = from; i <= last; i++) {'id': '$i'},
        ];
      }

      final result = await SupabaseRepository.paginatedFetch(
        fetchPage: fetchPage,
        pageSize: 2,
      );

      expect(result, hasLength(4));
      expect(pageCalls, equals([(0, 1), (2, 3), (4, 5)]));
    });
  });
}
