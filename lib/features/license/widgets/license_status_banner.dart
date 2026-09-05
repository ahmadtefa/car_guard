import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/license_models.dart';
import '../pages/license_page.dart' as license_page;
import '../providers/license_provider.dart';

/// The existing non-blocking license status surface shared by the dashboard
/// and its fullscreen route. Its activation/retry actions remain unchanged;
/// callers decide where to position it.
class LicenseStatusBanner extends ConsumerWidget {
  const LicenseStatusBanner({super.key, required this.status});

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              fit: FlexFit.loose,
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      softWrap: true,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(body, softWrap: true),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      widthFactor: 1.0,
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
                                    builder: (_) =>
                                        const license_page.LicensePage(),
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
            ),
          ],
        ),
      ),
    );
  }
}
