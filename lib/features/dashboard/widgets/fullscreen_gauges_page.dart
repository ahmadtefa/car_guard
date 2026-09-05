import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/license_models.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../../../features/license/providers/license_provider.dart';
import '../../../features/license/widgets/license_status_banner.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import 'fullscreen_hud_page.dart';
import 'gauge_area.dart';

/// Fullscreen view of the same four primary readings shown by the dashboard.
/// The content is fitted to the available viewport instead of being put in a
/// scroll view, so temperature, voltage difference, speed and distance remain
/// visible together on portrait and landscape screens.
class FullscreenGaugesPage extends ConsumerWidget {
  const FullscreenGaugesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final state = ref.watch(dashboardProvider);
    final settings = ref.watch(effectiveSettingsProvider);
    final settingsState = ref.watch(settingsProvider);
    final localSettings = settingsState.value;
    final license = ref.watch(licenseProvider);

    final showLicenseOverlay =
        !(localSettings?.demoModeEnabled ?? false) &&
        (localSettings == null || !license.canUseProtectedControls);
    final licenseStatus =
        localSettings == null && license.canUseProtectedControls
            ? LicenseCheckStatus.checking
            : license.checkStatus;

    void openHud(String type) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => FullscreenHudPage(type: type),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF040406),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = math.max(
                    1.0,
                    constraints.maxWidth - AppSpacing.xl,
                  ).toDouble();

                  return Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: contentWidth,
                        child: buildGaugeArea(
                          context,
                          ref,
                          settings: settings,
                          state: state,
                          l: l,
                          onOpenHud: openHud,
                          compact: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: l.close,
                icon: const Icon(Icons.close_fullscreen_rounded),
                color: Colors.white.withAlpha((255 * 0.7).round()),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (showLicenseOverlay)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: LicenseStatusBanner(status: licenseStatus),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
