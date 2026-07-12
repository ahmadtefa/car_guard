import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

/// Riverpod provider for exposing the notification infrastructure service contract.
///
/// This keeps the notification API abstract and makes future implementations
/// swappable through Riverpod.
/// TODO: Update this wiring when a platform notification implementation is added.
final notificationProvider = Provider<NotificationService>(
  (ref) => ref.watch(notificationServiceProvider),
);
