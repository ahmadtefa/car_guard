import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_spacing.dart';
import '../core/models/license_models.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/license/providers/license_provider.dart';
import '../features/license/widgets/license_status_banner.dart';
import '../features/settings/providers/settings_provider.dart';

/// Entry shell for the home route.
///
/// The shell never blocks on the license query. It opens the dashboard for a
/// normal device immediately; the dashboard shows placeholders until the
/// authoritative license is ACTIVE, while the banner and activation path stay
/// available. Demo mode continues to use the simulator.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final demoEnabled = settings?.demoModeEnabled ?? false;

    if (demoEnabled) {
      return const DashboardPage();
    }

    final license = ref.watch(licenseProvider);
    final status = settings == null && license.canUseProtectedControls
        ? LicenseCheckStatus.checking
        : license.checkStatus;

    return Stack(
      children: [
        const DashboardPage(),
        if (settings == null || !license.canUseProtectedControls)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: LicenseStatusBanner(status: status),
              ),
            ),
          ),
      ],
    );
  }
}
