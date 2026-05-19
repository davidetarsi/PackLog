import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'package_info_provider.g.dart';

/// Espone le informazioni del package (versione, nome, ecc.) come provider
/// Riverpod. Lette dinamicamente da `pubspec.yaml` via platform channel.
///
/// Uso:
/// ```dart
/// final info = ref.watch(packageInfoProvider);
/// info.when(
///   data: (pkg) => Text('v${pkg.version}'),
///   loading: () => Text('...'),
///   error: (_, __) => Text('—'),
/// );
/// ```
// ignore: deprecated_member_use_from_same_package
@Riverpod(keepAlive: true)
Future<PackageInfo> packageInfo(PackageInfoRef ref) =>
    PackageInfo.fromPlatform();
