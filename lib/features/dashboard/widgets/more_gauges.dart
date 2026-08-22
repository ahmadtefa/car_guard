import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// Five extra gauge designs for the dashboard (design pass 6):
/// neon ring, LED strip, analog needle, liquid orb and digital cluster.
/// All CustomPainter based — no extra dependencies.

// ============================================================
// 1. Neon Ring — smartwatch-style circular progress ring
// ============================================================
class NeonRingGauge extends StatelessWidget {
  const NeonRingGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.neonRed : AppColors.neonCyan;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: danger
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(132, 132),
                      painter: _NeonRingPainter(
                        percent: percent.clamp(0.0, 1.0),
                        danger: danger,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: danger
                                  ? AppColors.neonRed
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  _NeonRingPainter({required this.percent, required this.danger});

  final double percent;
  final bool danger;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const start = -math.pi / 2;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..color = Colors.white.withAlpha((255 * 0.07).round()),
    );

    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: start,
      endAngle: start + math.pi * 2,
      colors: const [
        AppColors.neonGreen,
        AppColors.neonCyan,
        AppColors.neonAmber,
        AppColors.neonRed,
      ],
      stops: const [0, 0.55, 0.8, 1],
    );

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 11;

    if (danger) {
      paint.color = AppColors.neonRed;

      canvas.drawArc(
        rect.inflate(5),
        start,
        percent * math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 19
          ..color = AppColors.neonRed.withAlpha(45),
      );
    } else {
      paint.shader = gradient.createShader(rect);
    }

    canvas.drawArc(rect, start, percent * math.pi * 2, false, paint);

    final knobAngle = start + percent * math.pi * 2;

    canvas.drawCircle(
      Offset(
        center.dx + radius * math.cos(knobAngle),
        center.dy + radius * math.sin(knobAngle),
      ),
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_NeonRingPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.danger != danger;
  }
}

// ============================================================
// 2. LED Strip — 20 glowing blocks like modern car clusters
// ============================================================
class LedStripGauge extends StatelessWidget {
  const LedStripGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final litCount = ((percent.clamp(0.0, 1.0)) * 20).round();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: danger
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: danger ? AppColors.neonRed : AppColors.neonCyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: danger
                          ? AppColors.neonRed
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: List.generate(20, (index) {
                  final lit = index < litCount;

                  final Color color;
                  if (danger) {
                    color = AppColors.neonRed;
                  } else if (index >= 17) {
                    color = AppColors.neonRed;
                  } else if (index >= 13) {
                    color = AppColors.neonAmber;
                  } else {
                    color = AppColors.neonGreen;
                  }

                  return Expanded(
                    child: Container(
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: lit
                            ? color
                            : Colors.white.withAlpha((255 * 0.07).round()),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: lit
                            ? [
                                BoxShadow(
                                  color: color.withAlpha(110),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 3. Needle Meter — horizontal VU-style sweeping needle
// ============================================================
class NeedleMeterGauge extends StatelessWidget {
  const NeedleMeterGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final bool danger;
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
            color: danger
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: danger ? AppColors.neonRed : AppColors.neonCyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: danger
                          ? AppColors.neonRed
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 92,
                width: double.infinity,
                child: CustomPaint(
                  painter: _NeedlePainter(
                    percent: percent.clamp(0.0, 1.0),
                    danger: danger,
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

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.percent, required this.danger});

  final double percent;
  final bool danger;

  static const double _sweepDeg = 100; // -50 .. +50

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (w < 60) return;

    final pivot = Offset(w / 2, h - 4);
    final radius = math.min(w / 2 - 6, h - 14).toDouble();

    Offset point(double deg, double r) {
      final rad = (deg - 90) * math.pi / 180;
      return Offset(
        pivot.dx + r * math.cos(rad),
        pivot.dy + r * math.sin(rad),
      );
    }

    // Colored zone arc.
    final zonePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;

    final zoneRect = Rect.fromCircle(center: pivot, radius: radius);

    if (!danger) {
      final gradient = SweepGradient(
        center: Alignment.center,
        startAngle: (-_sweepDeg / 2 - 90) * math.pi / 180,
        endAngle: (_sweepDeg / 2 - 90) * math.pi / 180,
        colors: const [
          AppColors.neonGreen,
          AppColors.neonCyan,
          AppColors.neonAmber,
          AppColors.neonRed,
        ],
        stops: const [0, 0.55, 0.8, 1],
      );
      zonePaint.shader = gradient.createShader(zoneRect);
    } else {
      zonePaint.color = AppColors.neonRed;
    }

    canvas.drawArc(
      zoneRect,
      (-_sweepDeg / 2 - 90) * math.pi / 180,
      _sweepDeg * math.pi / 180,
      false,
      zonePaint,
    );

    // Ticks.
    for (var i = 0; i <= 10; i++) {
      final deg = -_sweepDeg / 2 + (i / 10) * _sweepDeg;

      canvas.drawLine(
        point(deg, radius - 4),
        point(deg, radius + 4),
        Paint()
          ..strokeWidth = 1.5
          ..color = Colors.white.withAlpha((255 * 0.5).round()),
      );
    }

    // Needle.
    final needleDeg = -_sweepDeg / 2 + percent * _sweepDeg;
    final tip = point(needleDeg, radius - 10);

    final needlePaint =
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = danger ? AppColors.neonRed : Colors.white;

    if (danger) {
      canvas.drawLine(
        Offset.lerp(pivot, tip, 0.9)!,
        tip,
        Paint()
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = AppColors.neonRed.withAlpha(70),
      );
    }

    canvas.drawLine(pivot, tip, needlePaint);

    canvas.drawCircle(pivot, 6, Paint()..color = const Color(0xFF15151A));
    canvas.drawCircle(
      pivot,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = danger ? AppColors.neonRed : Colors.white.withAlpha(120),
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.danger != danger;
  }
}

// ============================================================
// 4. Liquid Orb — glass orb filling with a wavy liquid
// ============================================================
class LiquidOrbGauge extends StatelessWidget {
  const LiquidOrbGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final bool danger;
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
            color: danger
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: danger ? AppColors.neonRed : AppColors.neonCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(118, 118),
                      painter: _OrbPainter(
                        percent: percent.clamp(0.0, 1.0),
                        danger: danger,
                      ),
                    ),
                    Center(
                      child: Text(
                        '${value.toStringAsFixed(1)}\n$unit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withAlpha(235),
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.percent, required this.danger});

  final double percent;
  final bool danger;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;

    final orbRect = Rect.fromCircle(center: center, radius: radius);

    // Outer glass ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = danger
            ? AppColors.neonRed
            : AppColors.neonCyan.withAlpha((255 * 0.6).round()),
    );

    // Liquid fill clipped to the orb.
    canvas.save();
    canvas.clipPath(Path()..addOval(orbRect));

    final surfaceY = center.dy + radius - 2 * radius * percent;

    final wave = Path()
      ..moveTo(center.dx - radius, surfaceY)
      ..cubicTo(
        center.dx - radius / 2,
        surfaceY - 6,
        center.dx,
        surfaceY + 6,
        center.dx + radius / 2,
        surfaceY,
      )
      ..cubicTo(
        center.dx + radius * 0.85,
        surfaceY - 4,
        center.dx + radius,
        surfaceY,
        center.dx + radius,
        surfaceY,
      )
      ..lineTo(center.dx + radius, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy + radius)
      ..close();

    final liquid =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: danger
                ? const [Color(0x99FF2244), Color(0xCCFF2244)]
                : const [Color(0x9900D4FF), Color(0xCC00FF88)],
          ).createShader(orbRect);

    canvas.drawPath(wave, liquid);

    // Bubbles inside the liquid.
    final bubblePaint = Paint()..color = Colors.white.withAlpha(60);

    canvas.drawCircle(center.translate(-radius * 0.4, radius * 0.25), 4, bubblePaint);
    canvas.drawCircle(center.translate(radius * 0.3, radius * 0.4), 3, bubblePaint);
    canvas.drawCircle(center.translate(radius * 0.05, radius * 0.1), 2.5, bubblePaint);

    // Glass highlight.
    canvas.drawCircle(
      center.translate(-radius * 0.35, -radius * 0.4),
      radius * 0.18,
      Paint()..color = Colors.white.withAlpha(35),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.danger != danger;
  }
}

// ============================================================
// 5. Digital Cluster — 260° motorcycle-style ring with lit dots
// ============================================================
class DigitalClusterGauge extends StatelessWidget {
  const DigitalClusterGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final double value;
  final String unit;
  final double percent;
  final bool danger;
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
            color: danger
                ? AppColors.neonRed
                : AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: danger ? AppColors.neonRed : AppColors.neonCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: 150,
                height: 132,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(150, 132),
                      painter: _ClusterPainter(
                        percent: percent.clamp(0.0, 1.0),
                        danger: danger,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: danger ? AppColors.neonRed : null,
                            ),
                          ),
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClusterPainter extends CustomPainter {
  _ClusterPainter({required this.percent, required this.danger});

  final double percent;
  final bool danger;

  static const double _startDeg = 140;
  static const double _sweepDeg = 260;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final radius = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final start = (_startDeg) * math.pi / 180;
    final sweep = _sweepDeg * math.pi / 180;

    // Track.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withAlpha((255 * 0.08).round()),
    );

    // Lit tick dots along the arc.
    const dots = 14;

    for (var i = 0; i <= dots; i++) {
      final fraction = i / dots;
      final angle = start + fraction * sweep;

      final dotPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final lit = fraction <= percent;

      canvas.drawCircle(
        dotPos,
        lit ? 3.4 : 2.2,
        Paint()
          ..color = lit
              ? (danger
                    ? AppColors.neonRed
                    : fraction > 0.82
                    ? AppColors.neonRed
                    : fraction > 0.62
                    ? AppColors.neonAmber
                    : AppColors.neonGreen)
              : Colors.white.withAlpha((255 * 0.14).round()),
      );
    }

    // Main gradient arc inset inside the dots.
    final innerRect = Rect.fromCircle(center: center, radius: radius - 11);

    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: start,
      endAngle: start + sweep,
      colors: const [
        AppColors.neonGreen,
        AppColors.neonCyan,
        AppColors.neonAmber,
        AppColors.neonRed,
      ],
      stops: const [0, 0.55, 0.8, 1],
    );

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;

    if (danger) {
      paint.color = AppColors.neonRed;
    } else {
      paint.shader = gradient.createShader(innerRect);
    }

    canvas.drawArc(innerRect, start, percent * sweep, false, paint);
  }

  @override
  bool shouldRepaint(_ClusterPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.danger != danger;
  }
}
