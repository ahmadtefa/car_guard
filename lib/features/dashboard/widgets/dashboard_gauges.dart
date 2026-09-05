import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// Racing-style gauge: a huge number over a gradient progress bar.
class RacingGauge extends StatelessWidget {
  const RacingGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.warning,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = warning ? AppColors.neonRed : AppColors.neonCyan;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: warning
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: warning ? AppColors.neonRed : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.neonCyan,
                                warning
                                    ? AppColors.neonRed
                                    : AppColors.neonMagenta,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sporty analog gauge with a red needle, tick marks and a redline zone.
class SportyGauge extends StatelessWidget {
  const SportyGauge({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.redlineValue,
    required this.unit,
    required this.warning,
    required this.onTap,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double redlineValue;
  final String unit;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: warning
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final gaugeSize =
                      math.min(constraints.maxWidth, 170.0).toDouble();
                  return Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: gaugeSize,
                      height: gaugeSize,
                      child: CustomPaint(
                        painter: _SportyGaugePainter(
                          value: value,
                          min: min,
                          max: max,
                          redlineValue: redlineValue,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: warning ? AppColors.neonRed : null,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportyGaugePainter extends CustomPainter {
  _SportyGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.redlineValue,
  });

  final double value;
  final double min;
  final double max;
  final double redlineValue;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = w / 2;
    final r = w * 0.4;

    const start = -210 * math.pi / 180;
    const end = 30 * math.pi / 180;
    final range = end - start;

    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final angle = start + pct * range;

    // Gauge face.
    canvas.drawCircle(
      Offset(cx, cy),
      r + 4,
      Paint()..color = const Color(0xFF060608),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF22222A),
    );

    // Redline zone.
    final redPct = ((redlineValue - min) / (max - min)).clamp(0.0, 1.0);
    final redStart = start + redPct * range;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      redStart,
      end - redStart,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.neonRed.withAlpha((255 * 0.25).round()),
    );

    // Ticks and scale numbers.
    const steps = 8;
    for (var i = 0; i <= steps; i++) {
      final a = start + (i / steps) * range;

      final x1 = cx + (r - 5) * math.cos(a);
      final y1 = cy + (r - 5) * math.sin(a);
      final x2 = cx + r * math.cos(a);
      final y2 = cy + r * math.sin(a);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..strokeWidth = 1.5
          ..color = (i / steps) >= redPct
              ? AppColors.neonRed
              : Colors.white.withAlpha((255 * 0.8).round()),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${(min + (i / steps) * (max - min)).round()}',
          style: const TextStyle(
            color: Color(0xFF8E8E9C),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final nx = cx + (r - 16) * math.cos(a);
      final ny = cy + (r - 16) * math.sin(a);

      tp.paint(canvas, Offset(nx - tp.width / 2, ny - tp.height / 2));
    }

    // Needle.
    final needle = Path()
      ..moveTo(
        cx - 3 * math.cos(angle + math.pi / 2),
        cy - 3 * math.sin(angle + math.pi / 2),
      )
      ..lineTo(cx + (r - 8) * math.cos(angle), cy + (r - 8) * math.sin(angle))
      ..lineTo(
        cx + 3 * math.cos(angle + math.pi / 2),
        cy + 3 * math.sin(angle + math.pi / 2),
      )
      ..close();

    canvas.drawPath(needle, Paint()..color = AppColors.neonRed);

    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()..color = const Color(0xFF15151A),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF444444),
    );
  }

  @override
  bool shouldRepaint(_SportyGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.redlineValue != redlineValue;
  }
}

/// Vertical segmented meter: 12 blocks that light up bottom-to-top.
class SegmentedGauge extends StatelessWidget {
  const SegmentedGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.activeCount,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final int activeCount;
  final bool danger;
  final VoidCallback onTap;

  Color _blockColor(int segmentIndex) {
    if (danger) return AppColors.neonRed;
    if (segmentIndex >= 9) return AppColors.neonAmber;
    if (segmentIndex >= 6) return AppColors.neonGreen;
    return AppColors.neonCyan;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: danger
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.15).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 150,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  // Index 0 is the bottom block: segments fill bottom-to-top
                  // like the original Kayan HUD.
                  verticalDirection: VerticalDirection.up,
                  children: List.generate(12, (index) {
                    final active = index < activeCount;

                    return Container(
                      height: 7,
                      margin: const EdgeInsets.symmetric(vertical: 0.75),
                      decoration: BoxDecoration(
                        color: active
                            ? _blockColor(index)
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: danger ? AppColors.neonRed : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Audi-style horizontal sweeper: a trapezoid filled by a gradient.
class AudiSweeperGauge extends StatelessWidget {
  const AudiSweeperGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.gradientColors,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final List<Color> gradientColors;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SweeperPainter(
                    percent: percent,
                    gradientColors: gradientColors,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${value.toStringAsFixed(1)} $unit',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SweeperPainter extends CustomPainter {
  _SweeperPainter({required this.percent, required this.gradientColors});

  final double percent;
  final List<Color> gradientColors;

  Path _trapezoid(double w, double h, double fillWidth) {
    // The painter runs once with zero width during the first layout pass;
    // clamp(18, 0) would throw, so bail out until real constraints exist.
    if (w < 40 || h <= 0) return Path();

    final right = fillWidth.clamp(18.0, w);

    return Path()
      ..moveTo(0, h)
      ..lineTo(18, 5)
      ..lineTo(right, 5)
      ..lineTo(math.max(0.0, right - 18), h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (w < 40 || h <= 0) return;

    final full = _trapezoid(w, h, w);

    canvas.drawPath(
      full,
      Paint()..color = Colors.white.withAlpha((255 * 0.03).round()),
    );

    final fill = _trapezoid(w, h, (percent.clamp(0.0, 1.0)) * w);

    canvas.save();
    canvas.clipPath(fill);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint =
        Paint()
          ..shader = LinearGradient(colors: gradientColors).createShader(rect);

    canvas.drawRect(rect, paint);
    canvas.restore();

    canvas.drawPath(
      full,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withAlpha((255 * 0.06).round()),
    );
  }

  @override
  bool shouldRepaint(_SweeperPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}
