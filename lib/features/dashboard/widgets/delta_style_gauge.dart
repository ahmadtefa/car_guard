import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'mini_gauges.dart';

/// Voltage-difference gauge that follows the currently selected dashboard
/// style — the same visual language the Engine Temperature gauge uses for
/// that style — rendered as a positive-only magnitude:
///
/// * the displayed value is always the magnitude (a negative computed
///   delta is shown as its absolute value),
/// * zero sits at the START of the scale (left edge / dial start / bottom),
/// * the indicator moves in a single positive direction,
/// * there is no center-zero, no negative half and no counter-clockwise
///   sweep,
/// * null renders an empty track (never a fake 0.00).
///
/// The existing style gauges ([RacingGauge], [NeonRingGauge], ...) take an
/// unsigned percent starting at the scale start, so each branch below
/// mirrors one style's card, typography and geometry and simply feeds it
/// the voltage-difference magnitude. The classic 'cards' style uses
/// [VoltageDeltaCard] with the positive-only [DeltaGauge].
class StyledDeltaGauge extends StatelessWidget {
  const StyledDeltaGauge({
    super.key,
    required this.styleName,
    required this.delta,
    required this.label,
    this.unit = 'V',
    this.scale = 1.5,
    this.onTap,
  });

  /// One of AppSettings.dashboardStyleNames ('racing', 'sporty', ...).
  final String styleName;

  /// The difference to display as a magnitude; null renders an empty
  /// track. A negative input is rendered as its absolute value —
  /// display logic never draws a negative region.
  final double? delta;

  final String label;

  final String unit;

  /// Full-scale magnitude, in [unit]s.
  final double scale;

  final VoidCallback? onTap;

  /// Fill fraction in [0, 1]; 0 while [delta] is null.
  double get _fraction {
    final value = delta;
    if (value == null) return 0;
    return (value.abs() / scale).clamp(0.0, 1.0);
  }

  bool get _isEmpty => delta == null;

  Color get _accent {
    final value = delta;
    if (value == null || value.abs() < 0.005) return AppColors.neonCyan;
    return AppColors.neonGreen;
  }

  String get _valueText {
    final value = delta;
    if (value == null) return '--.- $unit';
    return '${value.abs().toStringAsFixed(2)} $unit';
  }

  /// Magnitude without the unit, for the center of the round gauges.
  String get _numberText {
    final value = delta;
    if (value == null) return '--.-';
    return value.abs().toStringAsFixed(2);
  }

  Widget _shell(BuildContext context, {required List<Widget> children}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.neonCyan.withAlpha((255 * 0.2).round()),
          ),
        ),
        child: Padding(
          padding: AppSpacing.padding,
          child: Column(children: children),
        ),
      ),
    );
  }

  Text _labelText() {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.neonCyan,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (styleName) {
      case 'racing':
        return _buildRacing(context);
      case 'sporty':
        return _buildSporty(context);
      case 'segments':
        return _buildSegments(context);
      case 'sweeper':
        return _buildSweeper(context);
      case 'ring':
        return _buildRing(context);
      case 'led':
        return _buildLed(context);
      case 'needle':
        return _buildNeedle(context);
      case 'orb':
        return _buildOrb(context);
      case 'combo':
        return _buildCluster(context);
      default:
        return _shell(context,
          children: [
            Align(alignment: Alignment.centerLeft, child: _labelText()),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _valueText,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: _isEmpty ? null : _accent,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DeltaGauge(delta: delta, scale: scale),
          ],
        );
    }
  }

  // ------------------------------------------------------------------
  // racing — big number over a gradient bar (see RacingGauge); the bar
  // fills from the left (zero at the start) in a cyan-to-green ramp.
  // ------------------------------------------------------------------
  Widget _buildRacing(BuildContext context) {
    return _shell(context,
      children: [
        Align(alignment: Alignment.centerLeft, child: _labelText()),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _valueText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: _isEmpty ? null : _accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 12,
          width: double.infinity,
          child: CustomPaint(painter: _RacingDeltaPainter(fraction: _fraction)),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // sporty — analog dial with needle (see SportyGauge); the dial spans
  // 0 .. scale with the zero at the start of the sweep.
  // ------------------------------------------------------------------
  Widget _buildSporty(BuildContext context) {
    return _shell(context,
      children: [
        CustomPaint(
          size: const Size(170, 170),
          painter: _SportyDeltaPainter(
            fraction: _fraction,
            scale: scale,
            empty: _isEmpty,
            accent: _accent,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _valueText,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: _isEmpty ? null : _accent,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _labelText(),
      ],
    );
  }

  // ------------------------------------------------------------------
  // segments — 12 blocks (see SegmentedGauge) lighting bottom-to-top,
  // zero at the bottom, all lit blocks green.
  // ------------------------------------------------------------------
  Widget _buildSegments(BuildContext context) {
    const blocks = 12;

    final lit = (_fraction * blocks).round();

    return _shell(context,
      children: [
        _labelText(),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 40,
          height: 150,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            // Index 0 is the bottom block, like SegmentedGauge: the zero
            // sits at the bottom and blocks light upward only.
            verticalDirection: VerticalDirection.up,
            children: List.generate(blocks, (index) {
              final active = !_isEmpty && index < lit;

              return Container(
                height: 7,
                margin: const EdgeInsets.symmetric(vertical: 0.75),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.neonGreen
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _valueText,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: _isEmpty ? null : _accent,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // sweeper — trapezoid sweep (see AudiSweeperGauge) filling from the
  // left start of the scale.
  // ------------------------------------------------------------------
  Widget _buildSweeper(BuildContext context) {
    return _shell(context,
      children: [
        Align(alignment: Alignment.centerLeft, child: _labelText()),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: CustomPaint(
            painter: _SweeperDeltaPainter(fraction: _fraction),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _valueText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: _isEmpty ? null : _accent,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // ring — smartwatch progress ring (see NeonRingGauge) sweeping from
  // the top start clockwise only.
  // ------------------------------------------------------------------
  Widget _buildRing(BuildContext context) {
    return _shell(context,
      children: [
        _labelText(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(132, 132),
                painter: _RingDeltaPainter(
                  fraction: _fraction,
                  empty: _isEmpty,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _numberText,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _isEmpty
                            ? Theme.of(context).colorScheme.onSurface
                            : _accent,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // led — 20 glowing blocks (see LedStripGauge) lighting left-to-right
  // from the zero start, all green.
  // ------------------------------------------------------------------
  Widget _buildLed(BuildContext context) {
    const blocks = 20;

    final lit = (_fraction * blocks).round();

    return _shell(context,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _labelText(),
            Text(
              _valueText,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _isEmpty
                    ? Theme.of(context).colorScheme.onSurface
                    : _accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // The strip reads left-to-right (zero at the left start): keep
        // blocks in canvas order even in RTL locales.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: List.generate(blocks, (index) {
              final litBlock = !_isEmpty && index < lit;

              return Expanded(
                child: Container(
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: litBlock
                        ? AppColors.neonGreen
                        : Colors.white.withAlpha((255 * 0.07).round()),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: litBlock
                        ? [
                            BoxShadow(
                              color: AppColors.neonGreen.withAlpha(110),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // needle — VU-style meter (see NeedleMeterGauge) with the needle
  // resting at the zero start (left) and moving clockwise only.
  // ------------------------------------------------------------------
  Widget _buildNeedle(BuildContext context) {
    return _shell(context,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _labelText(),
            Text(
              _valueText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _isEmpty
                    ? Theme.of(context).colorScheme.onSurface
                    : _accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 92,
          width: double.infinity,
          child: CustomPaint(
            painter: _NeedleDeltaPainter(
              fraction: _fraction,
              accent: _accent,
              empty: _isEmpty,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // orb — liquid orb (see LiquidOrbGauge): the liquid rises from the
  // bottom (zero) as the magnitude grows.
  // ------------------------------------------------------------------
  Widget _buildOrb(BuildContext context) {
    return _shell(context,
      children: [
        _labelText(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(118, 118),
                painter: _OrbDeltaPainter(
                  fraction: _fraction,
                  empty: _isEmpty,
                ),
              ),
              Center(
                child: Text(
                  '$_numberText\n$unit',
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
    );
  }

  // ------------------------------------------------------------------
  // combo — 260° cluster ring with lit dots (see DigitalClusterGauge)
  // lighting from the sweep start clockwise only.
  // ------------------------------------------------------------------
  Widget _buildCluster(BuildContext context) {
    return _shell(context,
      children: [
        _labelText(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 150,
          height: 132,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(150, 132),
                painter: _ClusterDeltaPainter(
                  fraction: _fraction,
                  empty: _isEmpty,
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _numberText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _isEmpty ? null : _accent,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================
// Painters — positive-only, zero-at-start adaptations of the style
// painters in dashboard_gauges.dart / more_gauges.dart.
// ======================================================================

/// racing bar: track + gradient fill from the left start of the scale.
class _RacingDeltaPainter extends CustomPainter {
  _RacingDeltaPainter({required this.fraction});

  /// Fill fraction in [0, 1].
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (w < 40) return;

    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 1, w, size.height - 2),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      barRect,
      Paint()..color = Colors.white.withAlpha((255 * 0.08).round()),
    );

    if (fraction > 0.003) {
      final fillWidth = fraction * w;
      final fill = Rect.fromLTWH(0, 1, fillWidth, size.height - 2);

      canvas.save();
      canvas.clipRRect(barRect);
      canvas.drawRect(
        fill,
        Paint()
          ..shader = const LinearGradient(
            colors: [AppColors.neonCyan, AppColors.neonGreen],
          ).createShader(fill),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RacingDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// sporty dial: 240° face from 0 to scale, zero at the sweep start.
class _SportyDeltaPainter extends CustomPainter {
  _SportyDeltaPainter({
    required this.fraction,
    required this.scale,
    required this.empty,
    required this.accent,
  });

  final double fraction;
  final double scale;
  final bool empty;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = w / 2;
    final r = w * 0.4;

    const start = -210 * math.pi / 180;
    const end = 30 * math.pi / 180;
    final range = end - start;

    final angle = start + fraction * range;

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

    // Single positive zone across the whole scale.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start,
      range,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.neonGreen.withAlpha((255 * 0.18).round()),
    );

    // Ticks and scale numbers: 0 .. scale (zero at the start).
    const steps = 4;
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final a = start + f * range;

      final isZero = i == 0;
      final x1 = cx + (r - (isZero ? 9 : 5)) * math.cos(a);
      final y1 = cy + (r - (isZero ? 9 : 5)) * math.sin(a);
      final x2 = cx + r * math.cos(a);
      final y2 = cy + r * math.sin(a);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..strokeWidth = isZero ? 2.5 : 1.5
          ..color = Colors.white
              .withAlpha((255 * (isZero ? 1.0 : 0.8)).round()),
      );

      final value = f * scale;
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(1),
          style: const TextStyle(
            color: Color(0xFF8E8E9C),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final nx = cx + (r - 18) * math.cos(a);
      final ny = cy + (r - 18) * math.sin(a);

      tp.paint(canvas, Offset(nx - tp.width / 2, ny - tp.height / 2));
    }

    if (empty) return;

    // Needle rises from the zero start of the sweep.
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

    canvas.drawPath(needle, Paint()..color = accent);

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
  bool shouldRepaint(_SportyDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.empty != empty ||
      oldDelegate.accent != accent;
}

/// sweeper trapezoid: filled from the left start of the scale.
class _SweeperDeltaPainter extends CustomPainter {
  _SweeperDeltaPainter({required this.fraction});

  final double fraction;

  /// Same slanted-sides trapezoid as the Audi sweeper: [right] bounds the
  /// filled span measured from the left edge (the zero start).
  Path _trapezoid(double w, double h, double fillWidth) {
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

    final fill = _trapezoid(w, h, fraction * w);

    canvas.save();
    canvas.clipPath(fill);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.neonGreen.withAlpha(80),
            AppColors.neonGreen,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
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
  bool shouldRepaint(_SweeperDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// neon ring: the value sweeps clockwise from the top start only.
class _RingDeltaPainter extends CustomPainter {
  _RingDeltaPainter({required this.fraction, required this.empty});

  final double fraction;
  final bool empty;

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

    if (empty || fraction < 0.003) return;

    final sweep = fraction * math.pi * 2;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 11
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + math.pi * 2,
          colors: const [AppColors.neonCyan, AppColors.neonGreen],
        ).createShader(rect),
    );

    final knobAngle = start + sweep;

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
  bool shouldRepaint(_RingDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.empty != empty;
}

/// VU needle: rises from the zero start (-50°) toward +50° only.
class _NeedleDeltaPainter extends CustomPainter {
  _NeedleDeltaPainter({
    required this.fraction,
    required this.accent,
    required this.empty,
  });

  final double fraction;
  final Color accent;
  final bool empty;

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

    final zoneRect = Rect.fromCircle(center: pivot, radius: radius);

    // Single positive zone across the whole scale.
    canvas.drawArc(
      zoneRect,
      (-_sweepDeg / 2 - 90) * math.pi / 180,
      _sweepDeg * math.pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.neonGreen.withAlpha((255 * 0.20).round()),
    );

    // Ticks; the first one marks the zero start.
    for (var i = 0; i <= 10; i++) {
      final deg = -_sweepDeg / 2 + (i / 10) * _sweepDeg;
      final isZero = i == 0;

      canvas.drawLine(
        point(deg, radius - (isZero ? 7 : 4)),
        point(deg, radius + 4),
        Paint()
          ..strokeWidth = isZero ? 2.5 : 1.5
          ..color = Colors.white.withAlpha((255 * (isZero ? 0.9 : 0.5)).round()),
      );
    }

    // Needle rises from the zero start; omitted while there is no reading
    // so null renders an empty track like the other styles.
    if (!empty) {
      final needleDeg = -_sweepDeg / 2 + fraction * _sweepDeg;
      final tip = point(needleDeg, radius - 10);

      canvas.drawLine(
        pivot,
        tip,
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );
    }

    canvas.drawCircle(pivot, 6, Paint()..color = const Color(0xFF15151A));
    canvas.drawCircle(
      pivot,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withAlpha(120),
    );
  }

  @override
  bool shouldRepaint(_NeedleDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.empty != empty ||
      oldDelegate.accent != accent;
}

/// liquid orb: the liquid level rises from the bottom (zero) as the
/// magnitude grows.
class _OrbDeltaPainter extends CustomPainter {
  _OrbDeltaPainter({required this.fraction, required this.empty});

  final double fraction;
  final bool empty;

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
        ..color = AppColors.neonCyan.withAlpha((255 * 0.6).round()),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(orbRect));

    if (!empty && fraction > 0.003) {
      // Liquid surface rises from the bottom with the magnitude.
      final surfaceY = center.dy + radius - 2 * radius * fraction;

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

      canvas.drawPath(
        wave,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x9900D4FF), Color(0xCC00FF88)],
          ).createShader(orbRect),
      );

      // Bubbles inside the liquid.
      final bubblePaint = Paint()..color = Colors.white.withAlpha(60);
      canvas.drawCircle(
        center.translate(-radius * 0.3, radius * (1 - fraction)),
        3,
        bubblePaint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.25, radius * (1 - fraction) - 10),
        2.5,
        bubblePaint,
      );
    }

    // Glass highlight.
    canvas.drawCircle(
      center.translate(-radius * 0.35, -radius * 0.4),
      radius * 0.18,
      Paint()..color = Colors.white.withAlpha(35),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.empty != empty;
}

/// digital cluster: 260° arc + dots lighting from the sweep start
/// clockwise only.
class _ClusterDeltaPainter extends CustomPainter {
  _ClusterDeltaPainter({required this.fraction, required this.empty});

  final double fraction;
  final bool empty;

  static const double _startDeg = 140;
  static const double _sweepDeg = 260;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final radius = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final start = _startDeg * math.pi / 180;
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

    // Dots along the arc, lit from the sweep start up to the magnitude.
    const dots = 14;

    for (var i = 0; i <= dots; i++) {
      final f = i / dots;
      final angle = start + f * sweep;

      final dotPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final lit = !empty && f <= fraction && fraction > 0.003;

      canvas.drawCircle(
        dotPos,
        lit ? 3.4 : 2.2,
        Paint()
          ..color = lit
              ? AppColors.neonGreen
              : Colors.white.withAlpha((255 * 0.14).round()),
      );
    }

    // Main arc from the sweep start.
    if (!empty && fraction > 0.003) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 11),
        start,
        fraction * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: const [AppColors.neonCyan, AppColors.neonGreen],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_ClusterDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.empty != empty;
}
