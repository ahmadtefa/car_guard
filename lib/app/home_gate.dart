import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/l10n/app_l10n.dart';
import '../core/models/license_models.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/license/pages/license_page.dart' as license_page;
import '../features/license/providers/license_provider.dart';
import '../features/settings/providers/settings_provider.dart';

/// Entry shell for the home route.
///
/// The shell never blocks on the license query. It opens the dashboard for a
/// normal device immediately; read-only telemetry remains visible while the
/// ESP8266 is LOCKED, while the banner and protected controls reflect the
/// authoritative license state. Demo mode continues to use the simulator.
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
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              top: false,
              child: _LicenseStatusBanner(status: status),
            ),
          ),
      ],
    );
  }
}

/// Small, non-blocking status surface over the normal dashboard. It makes the
/// protected-control state explicit without turning license checking into a
/// startup loading screen or hiding read-only telemetry.
class _LicenseStatusBanner extends ConsumerWidget {
  const _LicenseStatusBanner({required this.status});

  final LicenseCheckStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final (title, body, icon, color) = switch (status) {
      LicenseCheckStatus.checking => (
          l.licenseChecking,
          l.licenseCheckingInfo,
          Icons.sync_rounded,
          AppColors.neonAmber,
        ),
      LicenseCheckStatus.expired => (
          l.licenseExpired,
          l.licenseExpiredInfo,
          Icons.event_busy_rounded,
          AppColors.neonAmber,
        ),
      LicenseCheckStatus.invalid => (
          l.licenseInvalid,
          l.licenseInvalidInfo,
          Icons.gpp_bad_outlined,
          AppColors.danger,
        ),
      LicenseCheckStatus.noLicense => (
          l.licenseNoLicense,
          l.licenseNoLicenseInfo,
          Icons.lock_outline_rounded,
          AppColors.neonAmber,
        ),
      LicenseCheckStatus.error => (
          l.licenseNetworkUnavailable,
          l.licenseNetworkUnavailableInfo,
          Icons.cloud_off_rounded,
          AppColors.danger,
        ),
      LicenseCheckStatus.licensed => (
          '',
          '',
          Icons.check_circle_outline,
          AppColors.neonGreen,
        ),
    };

    if (status == LicenseCheckStatus.licensed) {
      return const SizedBox.shrink();
    }

    final retryable =
        status == LicenseCheckStatus.checking ||
        status == LicenseCheckStatus.error;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: retryable
                        ? TextButton.icon(
                            onPressed: () => ref
                                .read(licenseProvider.notifier)
                                .retryCheck(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l.retry),
                          )
                        : TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const license_page.LicensePage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.vpn_key_outlined),
                            label: Text(l.openLicense),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
