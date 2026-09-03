import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Abstract contract for HTTP infrastructure operations.
abstract class HttpService {
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, String>? headers,
  });

  Future<Map<String, dynamic>> postJson(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<void> close();
}

class HttpServiceImpl implements HttpService {
  HttpServiceImpl({
    http.Client? client,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 10);

  final http.Client _client;
  final Duration _timeout;

  @override
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _client
        .get(
          Uri.parse(url),
          headers: headers,
        )
        .timeout(
          _timeout,
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP GET failed (${response.statusCode})',
      );
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map,
    );
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            ...?headers,
          },
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(
          _timeout,
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP POST failed (${response.statusCode})',
      );
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map,
    );
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

final httpServiceProvider = Provider<HttpService>(
  (ref) => HttpServiceImpl(),
);
