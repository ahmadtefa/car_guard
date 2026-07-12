import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for HTTP infrastructure operations.
abstract class HttpService {
  /// Executes an HTTP GET request and returns a decoded JSON payload.
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, String>? headers,
  });

  /// Executes an HTTP POST request and returns a decoded JSON payload.
  Future<Map<String, dynamic>> postJson(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  /// Releases any underlying resources used by the client.
  Future<void> close();
}

/// Default placeholder implementation for HTTP infrastructure operations.
/// TODO: Replace this placeholder with an HTTP client implementation.
class HttpServiceImpl implements HttpService {
  @override
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, String>? headers,
  }) async {
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return <String, dynamic>{};
  }

  @override
  Future<void> close() async {}
}

/// Riverpod provider for exposing an HTTP service implementation.
final httpServiceProvider = Provider<HttpService>((ref) => HttpServiceImpl());
