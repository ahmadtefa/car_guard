import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for connectivity infrastructure operations.
abstract class ConnectivityService {
  /// Returns whether the device currently has a network connection.
  Future<bool> isConnected();

  /// Returns the current connection type as a string.
  Future<String> connectionType();
}

/// Placeholder implementation for connectivity infrastructure operations.
/// TODO: Replace this placeholder with a real connectivity implementation.
class ConnectivityServiceImpl implements ConnectivityService {
  @override
  Future<bool> isConnected() async => true;

  @override
  Future<String> connectionType() async => 'unknown';
}

/// Riverpod provider for exposing a connectivity service implementation.
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityServiceImpl(),
);
