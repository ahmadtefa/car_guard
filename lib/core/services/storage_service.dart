import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for local storage infrastructure operations.
abstract class StorageService {
  /// Writes a string value under the provided key.
  Future<void> write(String key, String value);

  /// Reads a string value for the provided key.
  Future<String?> read(String key);

  /// Deletes the value stored under the provided key.
  Future<void> delete(String key);

  /// Removes all stored values managed by this service.
  Future<void> clear();
}

/// Placeholder implementation for local storage infrastructure operations.
/// TODO: Replace this placeholder with a persistent storage implementation.
class StorageServiceImpl implements StorageService {
  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> clear() async {}
}

/// Riverpod provider for exposing a storage service implementation.
final storageServiceProvider = Provider<StorageService>((ref) => StorageServiceImpl());
