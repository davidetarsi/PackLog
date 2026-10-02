import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@Riverpod(keepAlive: true)
class ConnectivityNotifier extends _$ConnectivityNotifier {
  @override
  bool build() {
    final connectivity = Connectivity();

    connectivity.checkConnectivity().then((results) {
      state = _isConnected(results);
    });

    final subscription = connectivity.onConnectivityChanged.listen((results) {
      state = _isConnected(results);
    });

    ref.onDispose(subscription.cancel);

    return true;
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
