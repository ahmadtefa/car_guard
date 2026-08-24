import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/android_auto_bridge.dart';
import '../models/dashboard_state.dart';


final dashboardProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);


class DashboardNotifier extends Notifier<DashboardState> {

  @override
  DashboardState build() {

    ref.listen(
      deviceStatusProvider,
      (previous, next) {

        next.when(

          data: (deviceStatus) {

            // Mirror the live status to the Android Auto car UI.
            unawaited(
              AndroidAutoBridge.publishStatus(
                connected: deviceStatus.connected,
                engineTemperatureC: deviceStatus.connected
                    ? deviceStatus.temperatureData.engineTemperature
                    : null,
                batteryVoltage: deviceStatus.connected
                    ? deviceStatus.batteryData.voltage
                    : null,
                coolantAvailable: deviceStatus.connected
                    ? deviceStatus.coolantLevelData.coolantAvailable
                    : null,
                fanRunning: deviceStatus.connected
                    ? deviceStatus.controlData.fanRunning
                    : null,
              ),
            );

            state = DashboardState(

              connectionStatus:
                  deviceStatus.connected
                      ? 'Connected'
                      : 'Disconnected',


              engineTemperature:
                  '${deviceStatus.temperatureData.engineTemperature.toStringAsFixed(1)} °C',


              batteryVoltage:
                  '${deviceStatus.batteryData.voltage.toStringAsFixed(2)} V',


              voltageDifference:
                  state.voltageDifference,


              coolantLevel:
    deviceStatus.coolantLevelData.coolantAvailable
        ? 'Available'
        : 'Low',

fanStatus:
    deviceStatus.controlData.fanRunning
        ? 'ON'
        : 'OFF',

            );

          },


          loading: () {},


          error: (error, stackTrace) {

            // Let the Android Auto car UI know the device is offline.
            unawaited(AndroidAutoBridge.publishStatus(connected: false));

            state = const DashboardState(
              connectionStatus: 'Disconnected',
            );

          },

        );

      },

    );


    return const DashboardState();

  }

}