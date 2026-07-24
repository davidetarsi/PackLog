import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/helpers/sync_error_reason.dart';

void main() {
  group('syncErrorReasonKey', () {
    test('null error (never attempted) maps to unknown/generic key', () {
      expect(syncErrorReasonKey(null), 'profile.sync_reason_unknown');
    });

    test('SocketException-style network errors map to network key', () {
      expect(
        syncErrorReasonKey('SocketException: Failed host lookup: api.supabase.co'),
        'profile.sync_reason_network',
      );
      expect(
        syncErrorReasonKey('ClientException with SocketException: Connection timed out'),
        'profile.sync_reason_network',
      );
    });

    test('timeout errors map to network key', () {
      expect(
        syncErrorReasonKey('TimeoutException after 0:00:30.000000: Future not completed'),
        'profile.sync_reason_network',
      );
    });

    test('5xx / PostgrestException server errors map to server key', () {
      expect(
        syncErrorReasonKey('PostgrestException(message: internal error, code: 500)'),
        'profile.sync_reason_server',
      );
    });

    test('unrecognized error text maps to unknown/generic key', () {
      expect(
        syncErrorReasonKey('FormatException: Unexpected character'),
        'profile.sync_reason_unknown',
      );
    });

    test('empty string maps to unknown/generic key', () {
      expect(syncErrorReasonKey(''), 'profile.sync_reason_unknown');
    });
  });
}
