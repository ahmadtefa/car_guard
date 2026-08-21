import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Provider للتحكم في وضع القيادة - يحافظ على الشاشة شغالة
/// عند تفعيله، الشاشة لن تنطفئ تلقائياً لعرض البيانات بوضوح أثناء القيادة
final drivingModeProvider =
    NotifierProvider<DrivingModeNotifier, bool>(DrivingModeNotifier.new);

class DrivingModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.onDispose(() {
      WakelockPlus.disable();
    });
    return false;
  }

  /// تفعيل/إلغاء وضع القيادة
  Future<void> toggle() async {
    await setEnabled(!state);
  }

  /// تعيين حالة وضع القيادة مباشرة
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }
}
