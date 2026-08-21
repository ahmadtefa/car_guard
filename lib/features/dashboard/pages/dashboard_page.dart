import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/providers/alarm_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/dashboard_state.dart';
import '../providers/dashboard_provider.dart';
import '../providers/readings_history_provider.dart';
import '../widgets/compact_status_row.dart';
import '../widgets/fullscreen_hud_page.dart';
import '../widgets/fullscreen_gauges_page.dart';
import '../widgets/gauge_area.dart';
import '../widgets/module_limits_card.dart';
import '../widgets/reading_chart_card.dart';
import '../widgets/system_status_card.dart';

/// Full-screen dashboard.
///
/// Layout rules (design pass 3):
/// - The gauges live at the very top of the screen — nothing sits above
///   them except the floating control bar.
/// - The floating bar (language, connection state, style, settings) shows
///   on launch, auto-hides after 5 seconds and reappears on any touch.
/// - The small connection icon in the bar is the only connection status
///   indicator (green = connected, red = disconnected).
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const Duration _hideAfter = Duration(seconds: 5);

  bool _barVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _barVisible = false);
    });
  }

  void _onScreenTouched() {
    if (!_barVisible) {
      setState(() => _barVisible = true);
    }
    _scheduleHide();
  }

  void _showDataSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DataSheet(),
    );
  }

  Future<void> _toggleAlarmSound() async {
    final local = ref.read(settingsProvider).value ?? const AppSettings();

    final next = !local.alarmSoundEnabled;

    await ref
        .read(settingsProvider.notifier)
        .save(local.copyWith(alarmSoundEnabled: next));

    if (!next) {
      await ref.read(alarmServiceProvider).stop();

      if (!local.demoModeEnabled) {
        // Best-effort: also silence the module buzzer.
        await ref.read(esp8266RepositoryProvider).muteBuzzer();
      }
    }
  }

  void _showModuleInfo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _ModuleInfoSheet(),
    );
  }

  void _openHud(String type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenHudPage(type: type),
      ),
    );
  }

  void _showStylePicker() {
    final l = ref.read(l10nProvider);

    final settings = ref.read(settingsProvider).value ?? const AppSettings();

    final options = <(String, IconData, String)>[
      ('cards', Icons.dashboard_outlined, l.styleCards),
      ('racing', Icons.speed, l.styleRacing),
      ('sporty', Icons.donut_large_outlined, l.styleSporty),
      ('segments', Icons.view_week_outlined, l.styleSegments),
      ('sweeper', Icons.linear_scale_outlined, l.styleSweeper),
      ('ring', Icons.album_outlined, l.styleRing),
      ('led', Icons.lightbulb_outline, l.styleLed),
      ('needle', Icons.speed_outlined, l.styleNeedle),
      ('orb', Icons.water_drop_outlined, l.styleOrb),
      ('combo', Icons.data_usage_rounded, l.styleCombo),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l.dashboardStyle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              for (final (name, icon, label) in options)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing:
                      settings.dashboardStyleName == name
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .save(
                          (ref.read(settingsProvider).value ??
                                  const AppSettings())
                              .copyWith(dashboardStyleName: name),
                        );

                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundIconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.14).round()),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha((255 * 0.55).round())),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  Widget _buildFloatingBar({
    required bool connected,
    required bool demoEnabled,
    required AppL10n l,
    required String languageName,
  }) {
    return AnimatedOpacity(
      opacity: _barVisible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !_barVisible,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerLow.withAlpha(225),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.neonCyan.withAlpha((255 * 0.25).round()),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l.language,
                visualDensity: VisualDensity.compact,
                icon: Text(
                  languageName == 'ar' ? 'EN' : 'ع',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final local =
                      ref.read(settingsProvider).value ??
                      const AppSettings();

                  ref
                      .read(settingsProvider.notifier)
                      .save(
                        local.copyWith(
                          languageName:
                              local.languageName == 'ar' ? 'en' : 'ar',
                        ),
                      );
                },
              ),

              // Compact connection indicator — the only connection
              // status on the screen.
              Tooltip(
                message: connected ? l.connected : l.disconnected,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    connected
                        ? Icons.sensors_rounded
                        : Icons.sensors_off_rounded,
                    size: 22,
                    color: connected
                        ? AppColors.neonGreen
                        : AppColors.neonRed,
                  ),
                ),
              ),

              if (demoEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2),
                  child: Text(
                    'DEMO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              IconButton(
                tooltip: l.moduleInfo,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: _showModuleInfo,
              ),
              IconButton(
                tooltip: l.readingsAndCharts,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.insights_rounded),
                onPressed: _showDataSheet,
              ),
              IconButton(
                tooltip: l.fullscreenGauges,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.fullscreen_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const FullscreenGaugesPage(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: l.dashboardStyle,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.palette_outlined),
                onPressed: _showStylePicker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    final l = ref.watch(l10nProvider);

    final local = ref.watch(settingsProvider).value ?? const AppSettings();
    final settings = ref.watch(effectiveSettingsProvider);

    final connected = state.connectionStatus == 'Connected';

    return Scaffold(
      body: Listener(
        // Any touch — tap or scroll — reveals the floating bar again.
        onPointerDown: (_) => _onScreenTouched(),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gauges live at the very top of the screen.
                    buildGaugeArea(
                      context,
                      ref,
                      settings: settings,
                      state: state,
                      l: l,
                      onOpenHud: _openHud,
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Center(
                      child: Text(
                        '${l.lastUpdated}: ${state.lastUpdated}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    const FanAlternatorRow(),

                    const SizedBox(height: AppSpacing.md),

                    const SystemStatusCard(),

                    const SizedBox(height: AppSpacing.xl),

                    // Icon-only controls: mute + settings.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _roundIconButton(
                          tooltip: local.alarmSoundEnabled
                              ? l.muteAlarm
                              : l.enableAlarm,
                          icon: local.alarmSoundEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: local.alarmSoundEnabled
                              ? AppColors.neonAmber
                              : AppColors.textSecondary,
                          onTap: _toggleAlarmSound,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _roundIconButton(
                          tooltip: switch (local.themeModeName) {
                            'light' => l.light,
                            'dark' => l.dark,
                            _ => l.auto,
                          },
                          icon: switch (local.themeModeName) {
                            'light' => Icons.light_mode_outlined,
                            'dark' => Icons.dark_mode_outlined,
                            _ => Icons.brightness_auto_outlined,
                          },
                          color: AppColors.neonAmber,
                          onTap: () {
                            final next = switch (local.themeModeName) {
                              'system' => 'light',
                              'light' => 'dark',
                              _ => 'system',
                            };

                            ref
                                .read(settingsProvider.notifier)
                                .save(
                                  local.copyWith(themeModeName: next),
                                );
                          },
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _roundIconButton(
                          tooltip: l.settings,
                          icon: Icons.settings_outlined,
                          color: AppColors.neonCyan,
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Floating control bar over the gauges.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: true,
                bottom: false,
                minimum: const EdgeInsets.only(top: AppSpacing.xs),
                child: _buildFloatingBar(
                  connected: connected,
                  demoEnabled: local.demoModeEnabled,
                  l: l,
                  languageName: local.languageName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the module serial, install date and a settings
/// shortcut (the only settings entry point since the gear left the bar).
class _ModuleInfoSheet extends ConsumerStatefulWidget {
  const _ModuleInfoSheet();

  @override
  ConsumerState<_ModuleInfoSheet> createState() => _ModuleInfoSheetState();
}

class _ModuleInfoSheetState extends ConsumerState<_ModuleInfoSheet> {
  bool _loading = true;
  DeviceModuleSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final result =
        await ref.read(esp8266RepositoryProvider).getDeviceSettings();

    if (!mounted) return;

    setState(() {
      _settings = result;
      _loading = false;
    });
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.neonCyan),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.padding,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, color: AppColors.neonCyan),
              const SizedBox(width: AppSpacing.md),
              Text(l.moduleInfo, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_settings == null) ...[
            Text(l.cantReadModule, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(onPressed: _load, child: Text(l.retry)),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _row(
                      Icons.tag_rounded,
                      l.serialLabel,
                      (_settings!.serial.isEmpty) ? '--' : _settings!.serial,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _row(
                      Icons.calendar_month_outlined,
                      l.installedLabel,
                      (_settings!.installDate.isEmpty)
                          ? l.unknownDate
                          : _settings!.installDate,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
              child: Text(l.settings),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet holding the module limits, the live charts and the
/// module-settings shortcut — everything that used to clutter the
/// main screen.
class _DataSheet extends ConsumerWidget {
  const _DataSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final history = ref.watch(readingsHistoryProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.neonCyan),
                const SizedBox(width: AppSpacing.md),
                Text(
                  l.readingsAndCharts,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            ModuleLimitsCard(),

            const SizedBox(height: AppSpacing.md),

            ReadingChartCard(
              title: l.engineTemperature,
              values: history
                  .map((sample) => sample.engineTemperature)
                  .toList(),
              unit: '°C',
              color: AppColors.danger,
            ),

            const SizedBox(height: AppSpacing.md),

            ReadingChartCard(
              title: l.batteryVoltage,
              values: history
                  .map((sample) => sample.batteryVoltage)
                  .toList(),
              unit: 'V',
              color: AppColors.success,
            ),

            const SizedBox(height: AppSpacing.md),

            SecondaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
              child: Text(l.settings),
            ),
          ],
        ),
      ),
    );
  }
}
