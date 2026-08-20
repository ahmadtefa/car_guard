import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/device/pages/advanced_settings_page.dart';
import '../features/device/pages/device_settings_page.dart';
import '../features/settings/pages/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) =>
            const DashboardPage(),
      ),

      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) =>
            const SettingsPage(),
      ),

      GoRoute(
        path: '/device-settings',
        name: 'device-settings',
        builder: (context, state) =>
            const DeviceSettingsPage(),
      ),

      GoRoute(
        path: '/advanced-settings',
        name: 'advanced-settings',
        builder: (context, state) =>
            const AdvancedSettingsPage(),
      ),
    ],
  );
});