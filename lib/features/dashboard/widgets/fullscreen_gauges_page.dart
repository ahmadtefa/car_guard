import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/dashboard_state.dart';
import '../providers/dashboard_provider.dart';
import 'fullscreen_hud_page.dart';
import 'gauge_area.dart';

/// Fullscreen view of the live gauges in the currently selected style —
/// the same widgets the dashboard shows, scaled onto the whole screen.
class FullscreenGaugesPage extends ConsumerWidget {
  const FullscreenGaugesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final state = ref.watch(dashboardProvider);
    final settings = ref.watch(effectiveSettingsProvider);

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
            Center(
              child: SingleChildScrollView(
                padding: AppSpacing.padding,
                child: buildGaugeArea(
                  context,
                  ref,
                  settings: settings,
                  state: state,
                  l: l,
                  onOpenHud: openHud,
                ),
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
          ],
        ),
      ),
    );
  }
}
