import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../providers/dashboard_provider.dart';
import 'fullscreen_hud_page.dart';
import 'gauge_area.dart';

/// Fullscreen view of the live readings — the same widgets the dashboard
/// shows, scaled onto the whole screen.
///
/// In the default `cards` style this is the four readings (temperature, voltage
/// difference, speed, distance) filling the screen: two rows of two in portrait,
/// one row of four in landscape, and the type of each cell grows with the space
/// it got. Other styles keep their gauge pair, exactly as before.
///
/// Because [DashboardReadingsGrid] needs a *bounded* height to share between its
/// rows, the fullscreen grid is laid out directly in the body instead of inside
/// a scroll view (scroll views hand their child an unbounded height, which an
/// `Expanded` row can not be built in).
class FullscreenGaugesPage extends ConsumerWidget {
  const FullscreenGaugesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final state = ref.watch(dashboardProvider);
    final settings = ref.watch(effectiveSettingsProvider);

    final gridStyle = settings.dashboardStyleName == 'cards';

    void openHud(String type) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => FullscreenHudPage(type: type),
        ),
      );
    }

    final area = buildGaugeArea(
      context,
      ref,
      settings: settings,
      state: state,
      l: l,
      onOpenHud: openHud,
      fullscreen: gridStyle,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF040406),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: gridStyle
                    ? const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xxl,
                        AppSpacing.md,
                        AppSpacing.md,
                      )
                    : EdgeInsets.zero,
                child: gridStyle
                    ? area
                    : Center(
                        child: SingleChildScrollView(
                          padding: AppSpacing.padding,
                          child: area,
                        ),
                      ),
              ),
            ),

            // Explicit, labelled way out — enough to look at while driving,
            // and it works in both RTL and LTR.
            const PositionedDirectional(top: 6, end: 8, child: _ExitButton()),
          ],
        ),
      ),
    );
  }
}

class _ExitButton extends ConsumerWidget {
  const _ExitButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    return Material(
      color: Colors.white.withAlpha((255 * 0.12).round()),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fullscreen_exit_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                l.exitFullscreen,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
