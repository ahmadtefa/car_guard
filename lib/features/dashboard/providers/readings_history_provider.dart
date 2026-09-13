import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../license/providers/license_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Keeps a sliding window of live readings (about five minutes at one
/// reading per second) for the dashboard charts.
final readingsHistoryProvider =
    NotifierProvider<ReadingsHistoryNotifier, List<ReadingSample>>(
      ReadingsHistoryNotifier.new,
    );

class ReadingsHistoryNotifier extends Notifier<List<ReadingSample>> {
  static const int maxSamples = 300;
  bool _dataAccessAllowed = false;
  int _accessGeneration = 0;

  @override
  List<ReadingSample> build() {
    final generation = ++_accessGeneration;
    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    final demoEnabled = ref.watch(
      settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
    );
    // History is a view of real telemetry and must be cleared when the
    // authoritative module license is no longer ACTIVE. Demo mode remains
    // local and does not depend on the module license.
    final dataAccessAllowed =
        settingsReady &&
        (demoEnabled || ref.watch(licenseAuthorizationProvider));
    _dataAccessAllowed = dataAccessAllowed;

    if (!dataAccessAllowed) {
      // Do not leave values visible while persisted settings are still
      // loading; a real transport drop is represented by the status stream.
      return const <ReadingSample>[];
    }

    void appendStatus(DeviceStatus status) {
      if (!_dataAccessAllowed || generation != _accessGeneration) return;

      // A locked/expired module is represented as disconnected. Clear
      // history instead of retaining old sensor values in charts.
      if (!status.connected) {
        state = const <ReadingSample>[];
        return;
      }

      state = [
        ...state,
        ReadingSample(
          timestamp: status.lastUpdated,
          engineTemperature: status.temperatureData.engineTemperature,
          batteryVoltage: status.batteryData.voltage,
        ),
      ];

      if (state.length > maxSamples) {
        state = state.sublist(state.length - maxSamples);
      }
    }

    // Do not use fireImmediately here. A synchronous callback during
    // Notifier.build would be overwritten by the empty list returned below,
    // losing the first connected frame. Capture the current value explicitly
    // as the initial state, then append future stream updates normally.
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
}
