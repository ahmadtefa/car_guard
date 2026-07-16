import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_status_provider.dart';
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