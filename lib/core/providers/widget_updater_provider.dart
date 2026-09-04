import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/widget_service.dart';
import 'device_status_provider.dart';

/// يراقب تدفق البيانات الحية ويحدّث ويدجت الشاشة الرئيسية تلقائياً
/// حتى بدون فتح التطبيق، الويدجت يعرض آخر قراءة
final widgetUpdaterProvider = Provider<void>((ref) {
  ref.listen(
    deviceStatusProvider,
    (previous, next) {
      next.whenData((status) {
        WidgetService.update(status);
      });
    },
    fireImmediately: true,
  );
});
