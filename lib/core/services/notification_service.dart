import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Abstract contract for notification infrastructure operations.
abstract class NotificationService {
  /// Initializes notification infrastructure and configuration.
  Future<bool> initialize();

  /// Displays a local notification with the provided payload.
  Future<void> show({required String title, required String body});

  /// Clears any pending notifications managed by the service.
  Future<void> clear();
}

/// Local notification implementation built on `flutter_local_notifications`.
///
/// The plugin is initialized lazily so the app never blocks startup, and every
/// call is defensive: notification failures must never crash the dashboard.
class NotificationServiceImpl implements NotificationService {
  static const String _channelId = 'car_guard_alerts';
  static const String _channelName = 'Car Guard Alerts';
  static const String _channelDescription =
      'Warnings from your Car Guard vehicle monitor.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );

      final result = await _plugin.initialize(initializationSettings);
      _initialized = result ?? false;

      // Android 13+ requires a runtime permission for notifications.
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        try {
          await androidImpl.requestNotificationsPermission();
        } catch (_) {
          // Permission request is best-effort; banner logic still works.
        }
      }

      return _initialized;
    } catch (e) {
      debugPrint('NOTIFICATION INIT FAILED: $e');
      return false;
    }
  }

  @override
  Future<void> show({required String title, required String body}) async {
    final ready = await initialize();
    if (!ready) return;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(_nextId++, title, body, notificationDetails);
  }

  @override
  Future<void> clear() async {
    if (!_initialized) return;

    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Nothing meaningful to do if cancellation fails.
    }
  }
}

/// Riverpod provider for exposing a notification service implementation.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationServiceImpl(),
);
