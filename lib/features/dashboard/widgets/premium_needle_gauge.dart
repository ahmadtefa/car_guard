import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Premium circular gauge with one shared normalized scale for its arc,
/// ticks, labels, and needle.
class PremiumNeedleGauge extends StatelessWidget {
  const PremiumNeedleGauge({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    this.warning = false,
    this.temperature = false,
    this.onTap,
  });

  final String title;
  final double? value;
  final String unit;
  final double min;
  final double max;
  final bool warning;
  final bool temperature;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            children: [
              SizedBox(
                height: 230,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PremiumGaugePainter(
                    value: value,
                    min: min,
                    max: max,
                    accent: warning ? AppColors.neonRed : AppColors.neonCyan,
                    temperature: temperature,
                  ),
                ),
              ),
              Text(
                value == null
                    ? '--.- $unit'
                    : '${value!.toStringAsFixed(1)} $unit',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: warning ? AppColors.neonRed : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumGaugePainter extends CustomPainter {
  const _PremiumGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.temperature,
  });

  static const int majorTickCount = 6;
  static const int minorTicksPerMajor = 4;
  static const double startAngle = 135 * math.pi / 180;
  static const double sweepAngle = 270 * math.pi / 180;

  final double? value;
  final double min;
  final double max;
  final Color accent;
  final bool temperature;

  double _fraction(double? reading) {
    if (reading == null || max <= min) return 0;
    return ((reading - min) / (max - min)).clamp(0.0, 1.0).toDouble();
  }

  Offset _point(Offset center, double radius, double angle) {
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .52);
    final radius = math.min(size.width, size.height) * .37;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final fraction = _fraction(value);

    canvas.drawCircle(center, radius + 18, Paint()..color = Colors.black54);
    canvas.drawCircle(
      center,
      radius + 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = const LinearGradient(
          colors: [Colors.white38, Colors.white10, Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: radius + 16)),
    );
    canvas.drawCircle(
      center,
      radius + 10,
      Paint()..color = const Color(0xff10151d),
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = Colors.white10;
    canvas.drawArc(rect, startAngle, sweepAngle, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(rect, startAngle, sweepAngle * fraction, false, arc);
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: temperature
              ? [
                  AppColors.neonCyan,
                  AppColors.neonAmber,
                  AppColors.neonRed,
                ]
              : [AppColors.neonCyan, AppColors.neonMagenta],
        ).createShader(rect),
    );

    final minorStep = sweepAngle / (majorTickCount * minorTicksPerMajor);
    for (var index = 0;
        index <= majorTickCount * minorTicksPerMajor;
        index++) {
      final isMajor = index % minorTicksPerMajor == 0;
      final angle = startAngle + minorStep * index;
      final outer = _point(
        center,
        radius + (isMajor ? 10 : 7),
        angle,
      );
      final inner = _point(
        center,
        radius + (isMajor ? -4 : 2),
        angle,
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = isMajor ? Colors.white : Colors.white54
          ..strokeWidth = isMajor ? 2.4 : 1.1,
      );

      if (isMajor) {
        final tickFraction =
            index / (majorTickCount * minorTicksPerMajor);
        final labelValue = min + (max - min) * tickFraction;
        final painter = TextPainter(
          text: TextSpan(
            text: labelValue.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelCenter = _point(center, radius - 25, angle);
        painter.paint(
          canvas,
          labelCenter - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }

    final needleAngle = startAngle + sweepAngle * fraction;
    final tip = _point(center, radius - 5, needleAngle);
    final tail = _point(center, 18, needleAngle + math.pi);
    final side =
        Offset(-math.sin(needleAngle), math.cos(needleAngle)) * 4;
    final needle = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo((tip - side).dx, (tip - side).dy)
      ..lineTo((tail + side).dx, (tail + side).dy)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..color = accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      needle,
      Paint()..color = Colors.white.withAlpha(210),
    );
    canvas.drawCircle(
      center,
      11,
      Paint()..color = const Color(0xff080b10),
    );
    canvas.drawCircle(center, 6, Paint()..color = accent);
    canvas.drawCircle(center, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PremiumGaugePainter old) {
    return old.value != value ||
        old.min != min ||
        old.max != max ||
        old.accent != accent ||
        old.temperature != temperature;
  }
}
