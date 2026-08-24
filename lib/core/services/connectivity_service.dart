import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ConnectivityService {
  Future<bool> isConnected();

  Future<String> connectionType();

  /// Emits `true` whenever at least one network interface is available
  /// and `false` as soon as all of them disappear (e.g. WiFi turned off).
  ///
  /// Used to detect network drops immediately, because a dead interface
  /// never notifies open sockets by itself.
  Stream<bool> get connectivityStream;
}

class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  @override
  Future<String> connectionType() async {
    final result = await _connectivity.checkConnectivity();

    if (result.contains(ConnectivityResult.wifi)) {
      return 'wifi';
    }

    if (result.contains(ConnectivityResult.mobile)) {
      return 'mobile';
    }

    if (result.contains(ConnectivityResult.ethernet)) {
      return 'ethernet';
    }

    return 'none';
  }

  @override
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any(
        (result) => result != ConnectivityResult.none,
      ),
    );
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityServiceImpl(),
);
