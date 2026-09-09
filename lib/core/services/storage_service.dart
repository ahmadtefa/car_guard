import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StorageService {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);

  Future<void> clear();
}

class StorageServiceImpl implements StorageService {
  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _prefs;
    debugPrint(
      'TRIP TRACE storage.read key=$key prefs=${identityHashCode(prefs)} '
      'appSettings=${prefs.getString(key)}',
    );
    return prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageServiceImpl(),
);