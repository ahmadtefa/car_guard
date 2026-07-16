import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/device/pages/device_connection_page.dart';

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
        path: '/connection',
        name: 'connection',
        builder: (context, state) =>
            const DeviceConnectionPage(),
      ),
    ],
  );
});