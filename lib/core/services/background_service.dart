import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Keeps the device connection alive while the app is in the background.
///
/// On Android this runs a small foreground service in the same process:
/// Android can no longer suspend the WebSocket/polling timers when the app
/// is backgrounded or the screen turns off, the CPU and Wi-Fi radio stay
/// awake, and app traffic stays bound to the (internet-less) device hotspot.
///
/// On other platforms every call is a safe no-op.
class BackgroundConnectionService {
  static const MethodChannel _channel =
      MethodChannel('car_guard/background');

  bool _notificationPermissionRequested = false;

  /// Starts (or refreshes) the foreground keep-alive. Safe to call on every
  /// connection event; the native side is idempotent.
  Future<void> start() async {
    await _ensureNotificationPermission();

    try {
      await _channel.invokeMethod('start');
    } on MissingPluginException {
      // Platform without the native service (desktop, web, iOS).
    } on PlatformException catch (error) {
      debugPrint('BACKGROUND SERVICE START FAILED: $error');
    }
  }

  /// Stops the foreground keep-alive. Call this on an intentional
  /// disconnect so the app does not hold a wake lock needlessly.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on MissingPluginException {
      // Nothing running on this platform.
    } on PlatformException catch (error) {
      debugPrint('BACKGROUND SERVICE STOP FAILED: $error');
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (_notificationPermissionRequested) {
      return;
    }
    _notificationPermissionRequested = true;

    // Android 13+ asks for the notifications permission at runtime. The
    // foreground service works without it, but the status notification
    // stays hidden, so ask once.
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }
}

final backgroundConnectionServiceProvider =
    Provider<BackgroundConnectionService>(
  (ref) => BackgroundConnectionService(),
);
