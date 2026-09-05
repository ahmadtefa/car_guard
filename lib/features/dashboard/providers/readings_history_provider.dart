import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';
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
    // History is a read-only view of the same telemetry that the dashboard
    // displays, so it remains available while the module is LOCKED.
    final dataAccessAllowed = settingsReady;
    _dataAccessAllowed = dataAccessAllowed;

    if (!dataAccessAllowed) {
      // Do not leave values visible while persisted settings are still
      // loading; a real transport drop is represented by the status stream.
      return const <ReadingSample>[];
    }

    ref.listen(
      deviceStatusProvider,
      (previous, next) {
        if (generation != _accessGeneration) return;
        next.whenData((status) {
          if (!_dataAccessAllowed || generation != _accessGeneration) return;

          // Ignore disconnected payloads so charts don't drop to zero.
          if (!status.connected) return;

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
        });
      },
      fireImmediately: true,
    );

    return const <ReadingSample>[];
  }
}
