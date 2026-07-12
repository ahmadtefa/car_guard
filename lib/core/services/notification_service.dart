import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for notification infrastructure operations.
abstract class NotificationService {
  /// Initializes notification infrastructure and configuration.
  Future<bool> initialize();

  /// Displays a local notification with the provided payload.
  Future<void> show({required String title, required String body});

  /// Clears any pending notifications managed by the service.
  Future<void> clear();
}

/// Placeholder implementation for notification infrastructure operations.
/// TODO: Replace this placeholder with a platform notification implementation.
class NotificationServiceImpl implements NotificationService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> show({required String title, required String body}) async {}

  @override
  Future<void> clear() async {}
}

/// Riverpod provider for exposing a notification service implementation.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationServiceImpl(),
);
