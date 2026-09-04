import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_l10n.dart';
import '../core/models/license_models.dart';
import '../core/widgets/loading_view.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/license/models/license_state.dart';
import '../features/license/pages/license_page.dart' as license_page;
import '../features/license/providers/license_provider.dart';
import '../features/settings/providers/settings_provider.dart';

/// Entry gate for the home route.
///
/// Decides whether to show the normal dashboard or the license screen based on
/// the AUTHORITATIVE license status reported by the ESP8266. It never assumes a
/// device is licensed from cached Flutter state: [licenseProvider] re-queries
/// the module on every (re)connection, and this gate only shows the dashboard
/// once the module itself reports ACTIVE.
///
/// Demo mode bypasses the gate (it has no real device); in that mode the
/// simulated readings are shown directly.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoEnabled = ref.watch(
      settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
    );
    if (demoEnabled) {
      return const DashboardPage();
    }

    final state = ref.watch(licenseProvider);
    final l = ref.watch(l10nProvider);

    switch (state.status) {
      case LicenseDeviceStatus.active:
        return const DashboardPage();

      case LicenseDeviceStatus.locked:
        return const license_page.LicensePage();

      case LicenseDeviceStatus.unknown:
        // No definitive status yet (connecting / querying / device unreachable).
        // Never show telemetry until the module confirms it is active.
        return Scaffold(
          body: LoadingView(message: l.licenseChecking),
        );
    }
  }
}
