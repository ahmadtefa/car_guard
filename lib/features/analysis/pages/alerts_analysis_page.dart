import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/widgets/section_title.dart';
import '../../dashboard/providers/readings_history_provider.dart';
import '../models/analysis_models.dart';
import '../providers/analysis_provider.dart';
import '../services/analysis_engine.dart';

/// Local warning-tier accent (between the amber "notice" and red "danger").
const Color _kWarningOrange = Color(0xFFEA580C);

/// The "التنبيهات والتحليل" page: vehicle condition, current alerts,
/// behaviour analysis, probabilistic predictions, trip stats and the
/// persisted alert history — all computed locally on the phone.
class AlertsAnalysisPage extends ConsumerWidget {
  const AlertsAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final analysis = ref.watch(analysisProvider);
    final status = ref.watch(deviceStatusProvider).value;
    final history = ref.watch(readingsHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.alertsAnalysis),
        actions: [
          if (analysis.history.isNotEmpty)
            IconButton(
              tooltip: l.clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearHistory(context, ref, l),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1) Overall condition banner.
          _ConditionBanner(condition: analysis.condition, l: l),
          const SizedBox(height: AppSpacing.md),

          // 2) Currently active alerts.
          SectionTitle(title: l.currentAlertsTitle),
          if (analysis.activeAlerts.isEmpty)
            _EmptyNote(icon: Icons.check_circle_outline, text: l.noAlertsNow)
          else
            ...analysis.activeAlerts.map(
              (alert) => _CurrentAlertCard(alert: alert, l: l),
            ),
          const SizedBox(height: AppSpacing.md),

          // 3) Behaviour analysis of the current session.
          SectionTitle(
            title: l.behaviorAnalysisTitle,
            subtitle: l.behaviorAnalysisSub,
          ),
          _StatsGrid(analysis: analysis, l: l),
          const SizedBox(height: AppSpacing.sm),
          _SparklineCard(samples: history, l: l),
          const SizedBox(height: AppSpacing.sm),
          _BaselineCard(analysis: analysis, status: status, l: l),
          const SizedBox(height: AppSpacing.md),

          // 4) + 5) Predictions, each with its data-backed confidence.
          SectionTitle(
            title: l.predictionsTitle,
            subtitle: l.predictionsDisclaimer,
          ),
          if (analysis.predictions.isEmpty)
            _EmptyNote(icon: Icons.insights_outlined, text: l.noPredictions)
          else
            ...analysis.predictions.map(
              (prediction) =>
                  _PredictionCard(prediction: prediction, l: l),
            ),
          const SizedBox(height: AppSpacing.md),

          // 6) Persisted alert history.
          SectionTitle(title: l.historyTitle),
          if (analysis.history.isEmpty)
            _EmptyNote(icon: Icons.history_toggle_off, text: l.noAlertsYet)
          else
            ...analysis.history.map(
              (entry) => _HistoryCard(entry: entry, l: l),
            ),
          const SizedBox(height: AppSpacing.md),

          // 7) Current trip statistics (GPS-based, only when available).
          SectionTitle(title: l.tripStatsTitle),
          _TripStatsCard(trip: analysis.trip, l: l),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.clearHistoryConfirmTitle),
        content: Text(l.clearHistoryConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l.clearAction,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed ?? false) {
      await ref.read(analysisProvider.notifier).clearHistory();
    }
  }
}

// =====================================================================
// Condition banner
// =====================================================================

class _ConditionBanner extends StatelessWidget {
  const _ConditionBanner({required this.condition, required this.l});

  final VehicleCondition condition;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final (color, icon, word, sub) = switch (condition) {
      VehicleCondition.normal => (
          AppColors.success,
          Icons.check_circle_rounded,
          l.normal,
          l.conditionNormalSub,
        ),
      VehicleCondition.attention => (
          AppColors.warning,
          Icons.error_outline_rounded,
          l.needsAttention,
          l.conditionAttentionSub,
        ),
      VehicleCondition.warning => (
          _kWarningOrange,
          Icons.warning_amber_rounded,
          l.sevWarning,
          l.conditionWarningSub,
        ),
      VehicleCondition.danger => (
          AppColors.danger,
          Icons.dangerous_outlined,
          l.sevDanger,
          l.conditionDangerSub,
        ),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.carConditionTitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    word,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(sub, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Current alerts
// =====================================================================

class _CurrentAlertCard extends StatelessWidget {
  const _CurrentAlertCard({required this.alert, required this.l});

  final AnalysisAlert alert;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    final readings = readingsSummary(alert.readings, l);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(kindIcon(alert.kind), color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kindTitle(alert.kind, l),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      SeverityChip(severity: alert.severity, l: l),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    kindMessage(alert.kind, l, alert.readings),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (readings.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      readings,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Session-statistics grid
// =====================================================================

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.analysis, required this.l});

  final AnalysisState analysis;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final stats = analysis.stats;
    const dash = '—';

    String tempValue(double v, {int digits = 1}) =>
        '${v.toStringAsFixed(digits)}${l.celsiusUnit}';
    String voltValue(double v) =>
        '${v.toStringAsFixed(2)} ${l.unitVolt}';

    final delta = analysis.voltageDelta90s;
    final slope = analysis.tempSlopePerMin;

    final tiles = <Widget>[
      _StatTile(
        icon: Icons.thermostat_rounded,
        label: l.avgTempStat,
        value: stats.connectedSamples > 0 ? tempValue(stats.avgTemp) : dash,
      ),
      _StatTile(
        icon: Icons.whatshot_outlined,
        label: l.maxTempStat,
        value: stats.maxTemp > -999 ? tempValue(stats.maxTemp) : dash,
      ),
      _StatTile(
        icon: Icons.trending_up_rounded,
        label: l.tempRiseRateStat,
        value: slope != null
            ? '${slope.toStringAsFixed(2)} ${l.cPerMinUnit}'
            : dash,
      ),
      _StatTile(
        icon: Icons.warning_amber_rounded,
        label: l.warningCrossingsStat,
        value: '${stats.warningCrossings}',
      ),
      _StatTile(
        icon: Icons.air_rounded,
        label: l.fanOnTimeStat,
        value: stats.fanOnSeconds > 0
            ? formatDuration(stats.fanOnSeconds, l)
            : dash,
      ),
      _StatTile(
        icon: Icons.battery_std_outlined,
        label: l.avgVoltStat,
        value: stats.connectedSamples > 0 ? voltValue(stats.avgVoltage) : dash,
      ),
      _StatTile(
        icon: Icons.battery_1_bar_outlined,
        label: l.minVoltStat,
        value: stats.minVoltage < 999 ? voltValue(stats.minVoltage) : dash,
      ),
      _StatTile(
        icon: Icons.battery_full_outlined,
        label: l.maxVoltStat,
        value: stats.maxVoltage > -999 ? voltValue(stats.maxVoltage) : dash,
      ),
      _StatTile(
        icon: Icons.swap_vert_rounded,
        label: l.voltDeltaStat,
        value: delta != null
            ? '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} ${l.unitVolt}'
            : dash,
      ),
      _StatTile(
        icon: Icons.sync_problem_outlined,
        label: l.abnormalChangesStat,
        value: '${stats.abnormalVoltageChanges}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// =====================================================================
// Baseline comparison ("vs usual")
// =====================================================================

class _BaselineCard extends StatelessWidget {
  const _BaselineCard({
    required this.analysis,
    required this.status,
    required this.l,
  });

  final AnalysisState analysis;
  final DeviceStatus? status;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final baseline = analysis.baseline;

    if (!baseline.isUsable) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.query_stats_rounded,
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.vsUsualTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.baselineCollecting,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentTemp = status?.temperatureData.engineTemperature;
    final currentVolt = status?.batteryData.voltage;

    final tempDiff = currentTemp == null
        ? null
        : AnalysisEngine.tempVsBaseline(currentTemp, baseline);
    final voltDiff = currentVolt == null
        ? null
        : AnalysisEngine.voltVsBaseline(currentVolt, baseline);

    final lines = <String>[
      if (tempDiff != null)
        tempDiff.abs() < 3
            ? ''
            : tempDiff > 0
                ? l.tempHigherThanUsual(tempDiff.abs().toStringAsFixed(1))
                : l.tempLowerThanUsual(tempDiff.abs().toStringAsFixed(1)),
      if (voltDiff != null && voltDiff.abs() >= 0.4)
        voltDiff > 0
            ? l.voltHigherThanUsual(voltDiff.abs().toStringAsFixed(2))
            : l.voltLowerThanUsual(voltDiff.abs().toStringAsFixed(2)),
    ]..removeWhere((line) => line.isEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.vsUsualTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BaselineRow(
              label: l.currentTempLabel,
              usualLabel: l.usualTempLabel,
              current: currentTemp == null
                  ? '—'
                  : '${currentTemp.toStringAsFixed(1)}${l.celsiusUnit}',
              usual: '${baseline.avgTemp.toStringAsFixed(1)}${l.celsiusUnit}',
            ),
            const SizedBox(height: AppSpacing.xs),
            _BaselineRow(
              label: l.currentVoltLabel,
              usualLabel: l.usualTempLabel,
              current: currentVolt == null
                  ? '—'
                  : '${currentVolt.toStringAsFixed(2)} ${l.unitVolt}',
              usual:
                  '${baseline.avgVoltage.toStringAsFixed(2)} ${l.unitVolt}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lines.isEmpty
                  ? (status == null ? l.insufficientData : l.withinUsual)
                  : lines.join('\n'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BaselineRow extends StatelessWidget {
  const _BaselineRow({
    required this.label,
    required this.usualLabel,
    required this.current,
    required this.usual,
  });

  final String label;
  final String usualLabel;
  final String current;
  final String usual;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text('$label: $current', style: style)),
        Expanded(
          child: Text(
            '$usualLabel: $usual',
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Predictions
// =====================================================================

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction, required this.l});

  final Prediction prediction;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(prediction.severity);
    final confidence = prediction.confidence;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(predictionIcon(prediction.kind), color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    predictionText(prediction, l),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ConfidenceChip(confidence: confidence, l: l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence, required this.l});

  final int? confidence;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final text =
        confidence != null ? l.confidenceLabel(confidence!) : l.insufficientData;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style:
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
            ),
      ),
    );
  }
}

// =====================================================================
// Alert history
// =====================================================================

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.l});

  final AlertHistoryEntry entry;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(entry.severity);
    final readings = readingsSummary(entry.readings, l);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(kindIcon(entry.kind), color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kindTitle(entry.kind, l),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatDateTime(entry.timestamp, l.isAr),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (readings.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      readings,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SeverityChip(severity: entry.severity, l: l),
                if (entry.occurrences > 1) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.occurrencesLabel(entry.occurrences),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (entry.escalated) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.escalatedTag,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Trip statistics
// =====================================================================

class _TripStatsCard extends StatelessWidget {
  const _TripStatsCard({required this.trip, required this.l});

  final TripSummary trip;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    if (!trip.available) {
      return _EmptyNote(icon: Icons.gps_off_rounded, text: l.gpsOff);
    }

    final tiles = <Widget>[
      _StatTile(
        icon: Icons.route_rounded,
        label: l.tripDistance,
        value:
            '${trip.distanceKm.toStringAsFixed(2)} ${l.km}',
      ),
      _StatTile(
        icon: Icons.speed_rounded,
        label: l.avgSpeedStat,
        value: '${trip.avgSpeedKmh.toStringAsFixed(0)} ${l.kmh}',
      ),
      _StatTile(
        icon: Icons.speed_outlined,
        label: l.maxSpeedStat,
        value: '${trip.maxSpeedKmh.toStringAsFixed(0)} ${l.kmh}',
      ),
      _StatTile(
        icon: Icons.timer_outlined,
        label: l.tripDurationLabel,
        value: formatDuration(trip.durationSeconds, l),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

// =====================================================================
// Sparkline (simple local charts for the last ~5 minutes)
// =====================================================================

class _SparklineCard extends StatelessWidget {
  const _SparklineCard({required this.samples, required this.l});

  final List<ReadingSample> samples;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 5) {
      return _EmptyNote(
        icon: Icons.show_chart_rounded,
        text: l.collectingData,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.last5Minutes,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: [for (final s in samples) s.engineTemperature],
                  color: AppColors.danger,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const _LegendDot(color: AppColors.danger),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l.engineTempLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: [for (final s in samples) s.batteryVoltage],
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const _LegendDot(color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l.batteryVoltLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    var min = values.first, max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = (max - min).abs() < 1e-6 ? 1.0 : max - min;

    final line = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final step = size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height -
          ((values[i] - min) / span) * (size.height - 4) -
          2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

// =====================================================================
// Shared small widgets + formatting helpers
// =====================================================================

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child:
                  Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// Severity chip ("ملاحظة / تحذير / خطر").
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity, required this.l});

  final AnalysisSeverity severity;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    final text = switch (severity) {
      AnalysisSeverity.notice => l.sevNotice,
      AnalysisSeverity.warning => l.sevWarning,
      AnalysisSeverity.danger => l.sevDanger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color severityColor(AnalysisSeverity severity) => switch (severity) {
      AnalysisSeverity.notice => AppColors.warning,
      AnalysisSeverity.warning => _kWarningOrange,
      AnalysisSeverity.danger => AppColors.danger,
    };

IconData kindIcon(AnalysisAlertKind kind) => switch (kind) {
      AnalysisAlertKind.engineTempHigh => Icons.thermostat_rounded,
      AnalysisAlertKind.batteryLow => Icons.battery_alert_rounded,
      AnalysisAlertKind.batteryHigh => Icons.battery_alert_rounded,
      AnalysisAlertKind.voltageUnstable => Icons.bolt_rounded,
      AnalysisAlertKind.coolantLow => Icons.water_drop_outlined,
      AnalysisAlertKind.fanLongRun => Icons.air_rounded,
      AnalysisAlertKind.connectionLostDriving => Icons.wifi_off_rounded,
    };

IconData predictionIcon(PredictionKind kind) => switch (kind) {
      PredictionKind.overheatLikely => Icons.whatshot_outlined,
      PredictionKind.approachingLimit => Icons.trending_up_rounded,
      PredictionKind.tempRisingFasterThanUsual =>
        Icons.trending_up_outlined,
      PredictionKind.unusualVoltagePattern => Icons.bolt_rounded,
      PredictionKind.coolingSystemCheckSuggested =>
        Icons.handyman_outlined,
      PredictionKind.heatRepeatedAtLowSpeed => Icons.traffic_rounded,
    };

String kindTitle(AnalysisAlertKind kind, AppL10n l) => switch (kind) {
      AnalysisAlertKind.engineTempHigh => l.engineTempHighTitle,
      AnalysisAlertKind.batteryLow => l.batteryLowTitle,
      AnalysisAlertKind.batteryHigh => l.batteryHighTitle,
      AnalysisAlertKind.voltageUnstable => l.voltageUnstableTitle,
      AnalysisAlertKind.coolantLow => l.coolantLowTitle,
      AnalysisAlertKind.fanLongRun => l.fanLongRunTitle,
      AnalysisAlertKind.connectionLostDriving => l.connectionDrivingTitle,
    };

String kindMessage(
  AnalysisAlertKind kind,
  AppL10n l,
  Map<String, double> readings,
) {
  final temp = (readings['temp'] ?? 0).toStringAsFixed(1);
  final volt = (readings['volt'] ?? 0).toStringAsFixed(2);
  final voltMin = (readings['voltMin'] ?? 0).toStringAsFixed(2);
  final voltMax = (readings['voltMax'] ?? 0).toStringAsFixed(2);

  return switch (kind) {
    AnalysisAlertKind.engineTempHigh => l.engineTempHighMessage(temp),
    AnalysisAlertKind.batteryLow => l.batteryLowMessage(volt, voltMin),
    AnalysisAlertKind.batteryHigh => l.batteryHighMessage(volt, voltMax),
    AnalysisAlertKind.voltageUnstable => l.voltageUnstableMessage,
    AnalysisAlertKind.coolantLow => l.coolantLowMessage,
    AnalysisAlertKind.fanLongRun => l.fanLongRunMessage,
    AnalysisAlertKind.connectionLostDriving => l.connectionDrivingMessage,
  };
}

String predictionText(Prediction prediction, AppL10n l) =>
    switch (prediction.kind) {
      PredictionKind.overheatLikely =>
        l.predOverheatLikely(prediction.valueArg),
      PredictionKind.approachingLimit =>
        l.predApproachingLimit(prediction.valueArg),
      PredictionKind.tempRisingFasterThanUsual =>
        l.predTempRisingFast(prediction.valueArg),
      PredictionKind.unusualVoltagePattern =>
        l.predUnusualVoltage(prediction.valueArg),
      PredictionKind.coolingSystemCheckSuggested =>
        l.predCoolingCheck(prediction.valueArg),
      PredictionKind.heatRepeatedAtLowSpeed => l.predHeatLowSpeed,
    };

/// Compact "reading: value" line under alerts and history entries.
String readingsSummary(Map<String, double> readings, AppL10n l) {
  final parts = <String>[];
  final temp = readings['temp'];
  if (temp != null && temp > 0) {
    parts.add('${l.tempShort}: ${temp.toStringAsFixed(1)}${l.celsiusUnit}');
  }
  final volt = readings['volt'];
  if (volt != null && volt > 0) {
    parts.add('${l.voltShort}: ${volt.toStringAsFixed(2)}${l.unitVolt}');
  }
  final speed = readings['speed'];
  if (speed != null && speed > 1) {
    parts.add('${l.speedShort}: ${speed.toStringAsFixed(0)} ${l.kmh}');
  }
  return parts.join(' · ');
}

/// "24 Aug 2026 - 14:32" / "24 أغسطس 2026 - 14:32" with Latin digits.
String formatDateTime(DateTime time, bool isAr) {
  const arMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  const enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final months = isAr ? arMonths : enMonths;
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${months[time.month - 1]} ${time.year} - $hour:$minute';
}

/// "75ث" / "2د 5ث" / "1س 20د" — compact duration with localized units.
String formatDuration(int seconds, AppL10n l) {
  if (seconds < 60) return '$seconds${l.secondsShort}';
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    final rest = seconds % 60;
    return rest == 0
        ? '$minutes${l.minutesShort}'
        : '$minutes${l.minutesShort} $rest${l.secondsShort}';
  }
  final hours = minutes ~/ 60;
  final restMinutes = minutes % 60;
  return restMinutes == 0
      ? '$hours${l.hoursShort}'
      : '$hours${l.hoursShort} $restMinutes${l.minutesShort}';
}
