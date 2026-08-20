import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Professional mini gauges designed for the classic dashboard cards:
/// a semicircular temperature arc with danger glow, a zoned voltage bar
/// and a center-zero voltage delta gauge. All CustomPainter based.

/// Semicircular arc gauge with colored zones and a pulsing red glow while
/// [danger] is true.
class MiniArcGauge extends StatefulWidget {
  const MiniArcGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.warnValue,
    required this.criticalValue,
    required this.danger,
  });

  /// Current reading; null keeps the track only (no needle/knob).
  final double? value;
  final double min;
  final double max;
  final double warnValue;
  final double criticalValue;
  final bool danger;

  @override
  State<MiniArcGauge> createState() => _MiniArcGaugeState();
}

class _MiniArcGaugeState extends State<MiniArcGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.danger) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MiniArcGauge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.danger && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.danger && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 118),
          painter: _ArcGaugePainter(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            warnValue: widget.warnValue,
            criticalValue: widget.criticalValue,
            danger: widget.danger,
            pulse: widget.danger ? _pulse.value : 0,
          ),
        );
      },
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  _ArcGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.warnValue,
    required this.criticalValue,
    required this.danger,
    required this.pulse,
  });

  final double? value;
  final double min;
  final double max;
  final double warnValue;
  final double criticalValue;
  final bool danger;
  final double pulse;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (w < 40 || h < 40) return;

    final center = Offset(w / 2, h - 8);
    final radius = math.min(w / 2 - 14, h - 22).toDouble();

    // The semicircle sweeps from 180° (left) to 360° (right).
    const startAngle = math.pi;
    const sweep = math.pi;

    final total = max - min;
    final warnFraction = ((warnValue - min) / total).clamp(0.0, 1.0);
    final critFraction = ((criticalValue - min) / total).clamp(0.0, 1.0);

    final trackRect = Rect.fromCircle(center: center, radius: radius);

    // Base track.
    canvas.drawArc(
      trackRect,
      startAngle,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = Colors.white.withAlpha((255 * 0.06).round()),
    );

    // Colored zones (dimmed).
    void zone(double fromF, double toF, Color color) {
      canvas.drawArc(
        trackRect,
        startAngle + fromF * sweep,
        (toF - fromF) * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = color.withAlpha((255 * (danger ? 0.12 : 0.22)).round()),
      );
    }

    zone(0, warnFraction, AppColors.neonGreen);
    zone(warnFraction, critFraction, AppColors.neonAmber);
    zone(critFraction, 1, AppColors.neonRed);

    // Scale ticks + labels at 0 / 50 / 100 %.
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final angle = startAngle + fraction * sweep;

      final outer = Offset(
        center.dx + (radius + _stroke / 2 + 2) * math.cos(angle),
        center.dy + (radius + _stroke / 2 + 2) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - _stroke / 2 - 2) * math.cos(angle),
        center.dy + (radius - _stroke / 2 - 2) * math.sin(angle),
      );

      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = 1.5
          ..color = Colors.white.withAlpha((255 * 0.35).round()),
      );

      final labelValue = (min + fraction * total).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$labelValue',
          style: TextStyle(
            color: Colors.white.withAlpha((255 * 0.4).round()),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelPos = Offset(
        center.dx + (radius + 14) * math.cos(angle),
        center.dy + (radius + 14) * math.sin(angle),
      );

      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    final reading = value;

    if (reading == null) return;

    final progress = ((reading - min) / total).clamp(0.0, 1.0);

    // Bright value arc with a sweep gradient over the zones.
    // The shader rect is the gauge circle, so centering the sweep on it
    // aligns the gradient with the arc angles.
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: startAngle,
      endAngle: startAngle + sweep,
      colors: [
        AppColors.neonGreen,
        AppColors.neonCyan,
        AppColors.neonAmber,
        AppColors.neonRed,
      ],
      stops: [
        0,
        warnFraction.clamp(0.01, 0.99),
        critFraction.clamp(0.02, 0.999),
        1,
      ],
    );

    final valuePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _stroke
          ..shader = gradient.createShader(trackRect);

    if (danger) {
      valuePaint.color = AppColors.neonRed;
      valuePaint.shader = null;

      // Pulsing glow behind the arc while in danger.
      canvas.drawArc(
        trackRect.inflate(5),
        startAngle,
        progress * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _stroke + 10
          ..color = AppColors.neonRed.withAlpha((255 * (0.10 + 0.22 * pulse)).round()),
      );
    }

    canvas.drawArc(
      trackRect,
      startAngle,
      progress * sweep,
      false,
      valuePaint,
    );

    // Needle knob at the reading position.
    final knobAngle = startAngle + progress * sweep;
    final knobPos = Offset(
      center.dx + radius * math.cos(knobAngle),
      center.dy + radius * math.sin(knobAngle),
    );

    if (danger) {
      canvas.drawCircle(
        knobPos,
        9 + 3 * pulse,
        Paint()..color = AppColors.neonRed.withAlpha(70),
      );
    }

    canvas.drawCircle(
      knobPos,
      5,
      Paint()..color = danger ? AppColors.neonRed : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_ArcGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.danger != danger ||
        oldDelegate.pulse != pulse ||
        oldDelegate.warnValue != warnValue ||
        oldDelegate.criticalValue != criticalValue;
  }
}

/// Horizontal battery voltage bar with colored zones and threshold ticks.
class MiniVoltBarGauge extends StatelessWidget {
  const MiniVoltBarGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.lowValue,
    required this.highValue,
  });

  final double? value;
  final double min;
  final double max;
  final double lowValue;
  final double highValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 34),
      painter: _VoltBarPainter(
        value: value,
        min: min,
        max: max,
        lowValue: lowValue,
        highValue: highValue,
      ),
    );
  }
}

class _VoltBarPainter extends CustomPainter {
  _VoltBarPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.lowValue,
    required this.highValue,
  });

  final double? value;
  final double min;
  final double max;
  final double lowValue;
  final double highValue;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    if (w < 40) return;

    final barTop = 8.0;
    final barHeight = 12.0;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, w, barHeight),
      const Radius.circular(6),
    );

    double fraction(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0);

    final lowF = fraction(lowValue);
    final highF = fraction(highValue);

    // Dimmed zones: red | green | red.
    canvas.save();
    canvas.clipRRect(barRect);

    final zonePaint = (double fromF, double toF, Color color) => Paint()
      ..color = color.withAlpha((255 * 0.20).round());

    canvas.drawRect(
      Rect.fromLTRB(0, barTop, lowF * w, barTop + barHeight),
      zonePaint(0, lowF, AppColors.neonRed),
    );
    canvas.drawRect(
      Rect.fromLTRB(lowF * w, barTop, highF * w, barTop + barHeight),
      zonePaint(lowF, highF, AppColors.neonGreen),
    );
    canvas.drawRect(
      Rect.fromLTRB(highF * w, barTop, w, barTop + barHeight),
      zonePaint(highF, 1, AppColors.neonRed),
    );

    // Bright gradient fill up to the current value.
    final reading = value;
    if (reading != null) {
      final vF = fraction(reading);

      final gradient = LinearGradient(
        colors: [
          AppColors.neonRed,
          AppColors.neonAmber,
          AppColors.neonGreen,
          AppColors.neonAmber,
          AppColors.neonRed,
        ],
      );

      canvas.drawRect(
        Rect.fromLTRB(0, barTop, vF * w, barTop + barHeight),
        Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, 1)),
      );

      // Knob at the value position.
      canvas.drawCircle(
        Offset(vF * w, barTop + barHeight / 2),
        6,
        Paint()..color = Colors.white,
      );
    }

    canvas.restore();

    // Threshold ticks.
    void tick(double f) {
      canvas.drawLine(
        Offset(f * w, barTop - 3),
        Offset(f * w, barTop + barHeight + 3),
        Paint()
          ..strokeWidth = 1.5
          ..color = Colors.white.withAlpha((255 * 0.5).round()),
      );
    }

    tick(lowF);
    tick(highF);

    // Scale labels.
    void label(String text, double x, AlignmentBucket align) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withAlpha((255 * 0.4).round()),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      var dx = x - tp.width / 2;
      if (align == AlignmentBucket.left) dx = x;
      if (align == AlignmentBucket.right) dx = x - tp.width;

      tp.paint(canvas, Offset(dx, barTop + barHeight + 4));
    }

    label(min.toStringAsFixed(0), 0, AlignmentBucket.left);
    label(
      '${lowValue.toStringAsFixed(1)}–${highValue.toStringAsFixed(1)}',
      w / 2,
      AlignmentBucket.center,
    );
    label(max.toStringAsFixed(0), w, AlignmentBucket.right);
  }

  @override
  bool shouldRepaint(_VoltBarPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.lowValue != lowValue ||
        oldDelegate.highValue != highValue;
  }
}

enum AlignmentBucket { left, center, right }

/// Center-zero differential gauge: positive fills right (green), negative
/// fills left (red).
class DeltaGauge extends StatelessWidget {
  const DeltaGauge({super.key, required this.delta, this.scale = 1.5});

  /// The signed difference to display; null renders an empty track.
  final double? delta;

  /// Full-scale magnitude (both directions).
  final double scale;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 34),
      painter: _DeltaPainter(delta: delta, scale: scale),
    );
  }
}

class _DeltaPainter extends CustomPainter {
  _DeltaPainter({required this.delta, required this.scale});

  final double? delta;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    if (w < 40) return;

    final barTop = 8.0;
    final barHeight = 12.0;
    final center = w / 2;

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, w, barHeight),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      track,
      Paint()..color = Colors.white.withAlpha((255 * 0.06).round()),
    );

    // Center zero line.
    canvas.drawLine(
      Offset(center, barTop - 4),
      Offset(center, barTop + barHeight + 4),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withAlpha((255 * 0.55).round()),
    );

    final value = delta;

    if (value != null && value.abs() > 0.005) {
      final fraction = (value / scale).clamp(-1.0, 1.0);
      final fillWidth = fraction * (w / 2 - 2);
      final color = value > 0 ? AppColors.neonGreen : AppColors.neonRed;

      final fillRect = Rect.fromCenter(
        center: Offset(center + fillWidth / 2, barTop + barHeight / 2),
        width: fillWidth.abs(),
        height: barHeight,
      );

      final rrect = RRect.fromRectAndRadius(
        fillRect,
        const Radius.circular(6),
      );

      canvas.drawRRect(
        rrect.inflate(2.5),
        Paint()..color = color.withAlpha((255 * 0.18).round()),
      );
      canvas.drawRRect(rrect, Paint()..color = color);

      canvas.drawCircle(
        Offset(center + fillWidth, barTop + barHeight / 2),
        6,
        Paint()..color = Colors.white,
      );
    }

    // Scale labels.
    void label(String text, double x, bool alignRight) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withAlpha((255 * 0.4).round()),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final dx = alignRight ? x - tp.width : x - tp.width / 2;

      tp.paint(canvas, Offset(dx, barTop + barHeight + 4));
    }

    label('-$scale', 0, false);
    label('0', center, false);
    label('+$scale', w, true);
  }

  @override
  bool shouldRepaint(_DeltaPainter oldDelegate) {
    return oldDelegate.delta != delta;
  }
}
