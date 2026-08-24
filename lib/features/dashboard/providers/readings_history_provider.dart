import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';

/// Keeps a sliding window of live readings (about five minutes at one
/// reading per second) for the dashboard charts.
final readingsHistoryProvider =
    NotifierProvider<ReadingsHistoryNotifier, List<ReadingSample>>(
      ReadingsHistoryNotifier.new,
    );

class ReadingsHistoryNotifier extends Notifier<List<ReadingSample>> {
  static const int maxSamples = 300;

  @override
  List<ReadingSample> build() {
    ref.listen(deviceStatusProvider, (previous, next) {
      next.whenData((status) {
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
    });

    return const <ReadingSample>[];
  }
}
