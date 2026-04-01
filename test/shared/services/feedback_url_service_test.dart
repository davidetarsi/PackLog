import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pack_log/features/profile/services/feedback_url_service.dart';

/// Stub di [PackageInfo] usato nei test.
///
/// Restituisce dati statici senza richiedere canali nativi, evitando
/// [MissingPluginException] nell'ambiente di test VM puro.
PackageInfo _stubPackageInfo({
  String version = '1.2.3',
  String buildNumber = '42',
}) =>
    PackageInfo(
      appName: 'PackLog',
      packageName: 'com.example.pack_log',
      version: version,
      buildNumber: buildNumber,
      buildSignature: '',
    );

/// Factory di stub iniettata nei test al posto di [PackageInfo.fromPlatform].
Future<PackageInfo> _stubFactory({
  String version = '1.2.3',
  String buildNumber = '42',
}) async =>
    _stubPackageInfo(version: version, buildNumber: buildNumber);

/// Costruisce un [FeedbackUrlService] con il factory stub.
FeedbackUrlService _makeService({
  String version = '1.2.3',
  String buildNumber = '42',
}) =>
    FeedbackUrlService(
      packageInfoFactory: () => _stubFactory(
        version: version,
        buildNumber: buildNumber,
      ),
    );

void main() {
  // ── FeedbackUrlResult ──────────────────────────────────────────────────────
  group('FeedbackUrlResult', () {
    test('stores uri, appVersion and os correctly', () {
      final uri = Uri.parse('https://example.com');
      final result = FeedbackUrlResult(
        uri: uri,
        appVersion: '1.2.3+4',
        os: 'android',
      );

      expect(result.uri, uri);
      expect(result.appVersion, '1.2.3+4');
      expect(result.os, 'android');
    });
  });

  // ── FeedbackUrlService.build() ─────────────────────────────────────────────
  group('FeedbackUrlService.build()', () {
    test('returns a FeedbackUrlResult', () async {
      final result = await _makeService().build();
      expect(result, isA<FeedbackUrlResult>());
    });

    test('uri scheme is https', () async {
      final result = await _makeService().build();
      expect(result.uri.scheme, 'https');
    });

    test('uri host is non-empty', () async {
      final result = await _makeService().build();
      expect(result.uri.host, isNotEmpty);
    });

    test('uri has at least two query parameters (os + version)', () async {
      final result = await _makeService().build();
      expect(result.uri.queryParameters.length, greaterThanOrEqualTo(2));
    });

    test('uri contains the OS value as a query parameter', () async {
      final result = await _makeService().build();
      final params = result.uri.queryParameters;

      expect(
        params.values,
        contains(Platform.operatingSystem),
        reason: 'OS deve essere iniettato come valore di un query parameter',
      );
    });

    test('uri contains the app version value as a query parameter', () async {
      final result = await _makeService(version: '2.0.0', buildNumber: '7').build();
      final params = result.uri.queryParameters;

      expect(
        params.values,
        contains('2.0.0+7'),
        reason: 'La versione "version+buildNumber" deve essere un query parameter',
      );
    });

    test('appVersion field matches version+buildNumber format', () async {
      final result = await _makeService(version: '3.1.4', buildNumber: '15').build();
      expect(result.appVersion, '3.1.4+15');
    });

    test('os field equals Platform.operatingSystem', () async {
      final result = await _makeService().build();
      expect(result.os, Platform.operatingSystem);
    });

    test('uri can be re-parsed without data loss (correct encoding)', () async {
      final result = await _makeService().build();
      final reparsed = Uri.parse(result.uri.toString());

      // Il re-parsing deve produrre gli stessi query parameters.
      expect(reparsed.queryParameters, result.uri.queryParameters);
    });

    test('uri toString() does not throw', () async {
      final result = await _makeService().build();
      expect(() => result.uri.toString(), returnsNormally);
    });

    test('build() is idempotent: same OS and parameter keys across calls', () async {
      final service = _makeService();
      final r1 = await service.build();
      final r2 = await service.build();

      expect(r1.os, r2.os);
      expect(
        r1.uri.queryParameters.keys.toSet(),
        r2.uri.queryParameters.keys.toSet(),
      );
    });

    test('different version stubs produce different appVersion in result', () async {
      final r1 = await _makeService(version: '1.0.0', buildNumber: '1').build();
      final r2 = await _makeService(version: '2.0.0', buildNumber: '99').build();

      expect(r1.appVersion, isNot(r2.appVersion));
    });
  });
}
