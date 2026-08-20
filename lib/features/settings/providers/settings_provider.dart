import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/storage_service.dart';

/// Exposes the persisted [AppSettings] and saves them back to storage.
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
      SettingsNotifier.new,
    );

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final storage = ref.read(storageServiceProvider);
    final raw = await storage.read(AppSettings.storageKey);

    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }

    return AppSettings.fromRaw(raw);
  }

  /// Updates the in-memory settings and persists them.
  Future<void> update(AppSettings settings) async {
    // Apply the value immediately; persistence failure must not break the
    // running session, so the in-memory state stays authoritative.
    state = AsyncData(settings);

    try {
      final storage = ref.read(storageServiceProvider);
      await storage.write(AppSettings.storageKey, settings.encode());
    } catch (e) {
      debugPrint('SETTINGS PERSIST FAILED: $e');
    }
  }
}
