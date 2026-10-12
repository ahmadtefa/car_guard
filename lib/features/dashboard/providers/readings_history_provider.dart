import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/license_models.dart';
import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/services/storage_service.dart';
import '../../license/providers/license_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Keeps a bounded rolling history of live readings and restores it between
/// launches while access to the real module (or Demo mode) is allowed.
final readingsHistoryProvider =
    NotifierProvider<ReadingsHistoryNotifier, List<ReadingSample>>(
      ReadingsHistoryNotifier.new,
    );

class ReadingsHistoryNotifier extends Notifier<List<ReadingSample>> {
  static const int maxSamples = 300;
  static const String storageKey = 'readings_history_v1';
  static const int _persistEverySamples = 10;

  bool _dataAccessAllowed = false;
  int _accessGeneration = 0;
  int _samplesSincePersist = 0;

  @override
  List<ReadingSample> build() {
    final generation = ++_accessGeneration;
    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    final demoEnabled = ref.watch(
      settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
    );
    final licenseRejected = ref.watch(
      licenseProvider.select(
        (value) =>
            value.isLocked &&
            value.checkStatus != LicenseCheckStatus.checking &&
            value.checkStatus != LicenseCheckStatus.error,
      ),
    );
    final dataAccessAllowed =
        settingsReady &&
        (demoEnabled || ref.watch(licenseAuthorizationProvider));
    _dataAccessAllowed = dataAccessAllowed;

    final storage = ref.read(storageServiceProvider);
    if (!dataAccessAllowed) {
      // Settings and license checks can be transiently unavailable during
      // startup or a network outage. Only erase protected history after an
      // authoritative LOCKED response has been received. An ACTIVE status
      // temporarily marked Checking/Error must never erase the saved history.
      if (settingsReady && !demoEnabled && licenseRejected) {
        unawaited(storage.delete(storageKey));
      }
      return const <ReadingSample>[];
    }

    unawaited(_restoreHistory(storage, generation));

    void appendStatus(DeviceStatus status) {
      if (!_dataAccessAllowed || generation != _accessGeneration) return;

      // A disconnect does not invalidate readings already collected during
      // an authorized session. License loss is handled above and clears them.
      if (!status.connected) return;

      final sample = ReadingSample(
        timestamp: status.lastUpdated,
        engineTemperature: status.temperatureData.engineTemperature,
        batteryVoltage: status.batteryData.voltage,
      );
      final updated = [...state, sample];
      state = updated.length > maxSamples
          ? updated.sublist(updated.length - maxSamples)
          : updated;

      _samplesSincePersist++;
      if (_samplesSincePersist >= _persistEverySamples) {
        _samplesSincePersist = 0;
        unawaited(_persistHistory(storage, state, generation));
      }
    }

    ref.listen(
      deviceStatusProvider,
      (previous, next) {
        if (generation != _accessGeneration) return;
        next.whenData(appendStatus);
      },
    );

    final currentStatus = ref.read(deviceStatusProvider).value;
    if (currentStatus != null && currentStatus.connected) {
      return [
        ReadingSample(
          timestamp: currentStatus.lastUpdated,
          engineTemperature: currentStatus.temperatureData.engineTemperature,
          batteryVoltage: currentStatus.batteryData.voltage,
        ),
      ];
    }

    return const <ReadingSample>[];
  }

  Future<void> _restoreHistory(
    StorageService storage,
    int generation,
  ) async {
    try {
      final raw = await storage.read(storageKey);
      if (raw == null || raw.isEmpty ||
          !_dataAccessAllowed ||
          generation != _accessGeneration) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = decoded
          .map(ReadingSample.fromJson)
          .whereType<ReadingSample>()
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (!_dataAccessAllowed || generation != _accessGeneration) return;

      // Merge restored and newly arrived samples, de-duplicating timestamps.
      final merged = <String, ReadingSample>{
        for (final sample in restored) sample.timestamp.toIso8601String(): sample,
        for (final sample in state) sample.timestamp.toIso8601String(): sample,
      }.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      state = merged.length > maxSamples
          ? merged.sublist(merged.length - maxSamples)
          : merged;
    } catch (_) {
      // Corrupt history must never prevent the live dashboard from working.
    }
  }

  Future<void> _persistHistory(
    StorageService storage,
    List<ReadingSample> samples,
    int generation,
  ) async {
    if (!_dataAccessAllowed || generation != _accessGeneration) return;
    try {
      final bounded = samples.length > maxSamples
          ? samples.sublist(samples.length - maxSamples)
          : samples;
      await storage.write(
        storageKey,
        jsonEncode(bounded.map((sample) => sample.toJson()).toList()),
      );
    } catch (_) {
      // Storage is best-effort; telemetry remains available in memory.
    }
  }
}
