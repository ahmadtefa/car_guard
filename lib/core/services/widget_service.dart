import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'device_models.dart';

/// يحدّث ويدجت الشاشة الرئيسية 2×1 في كل مرة تأتي قراءة جديدة
/// يكتب البيانات في SharedPreferences الخاصة بالويدجت ثم يطلب تحديثه
abstract final class WidgetService {
  static const _androidWidgetName = 'CarGuardWidgetProvider';

  static Future<void> update(DeviceStatus status) async {
    try {
      final temp = status.connected
          ? '${status.temperatureData.engineTemperature.toStringAsFixed(1)}°C'
          : '--°C';
      final volt = status.connected
          ? '${status.batteryData.voltage.toStringAsFixed(2)}V'
          : '--V';
      final fan = status.controlData.fanRunning ? 'ON' : 'OFF';
      final connected = status.connected;
      final maxTemp = status.moduleLimits.maxTemp?.toStringAsFixed(0) ?? '97';
      final alarm = status.controlData.buzzerActive;

      await HomeWidget.saveWidgetData<String>('widget_temp', temp);
      await HomeWidget.saveWidgetData<String>('widget_volt', volt);
      await HomeWidget.saveWidgetData<String>('widget_fan', fan);
      await HomeWidget.saveWidgetData<bool>('widget_connected', connected);
      await HomeWidget.saveWidgetData<String>('widget_max_temp', maxTemp);
      await HomeWidget.saveWidgetData<bool>('widget_alarm', alarm);

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.example.car_guard.$_androidWidgetName',
      );
    } catch (e) {
      debugPrint('WIDGET UPDATE FAILED: $e');
    }
  }

  static Future<void> updateDisconnected() async {
    await update(DeviceStatus.disconnected());
  }
}
