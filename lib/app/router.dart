import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/analysis/pages/alerts_analysis_page.dart';
import '../features/device/pages/advanced_settings_page.dart';
import '../features/device/pages/ota_update_page.dart';
import '../features/settings/pages/settings_page.dart';
import 'home_gate.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) =>
            const HomeGate(),
      ),

      GoRoute(
        path: '/alerts-analysis',
        name: 'alerts-analysis',
        builder: (context, state) =>
            const AlertsAnalysisPage(),
      ),

      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) =>
            const SettingsPage(),
      ),

      GoRoute(
        path: '/ota-update',
        name: 'ota-update',
        builder: (context, state) =>
            const OtaUpdatePage(),
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