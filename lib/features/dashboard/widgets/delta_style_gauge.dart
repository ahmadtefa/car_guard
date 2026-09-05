import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'mini_gauges.dart';

/// Voltage-difference gauge that follows the currently selected dashboard
/// style — the same visual language the Engine Temperature gauge uses for
/// that style — adapted to a signed, center-zero reading:
///
/// * zero stays at the center of the gauge,
/// * a positive value fills to the right (or clockwise) in green,
/// * a negative value fills to the left (or counter-clockwise) in red,
/// * null renders an empty track.
///
/// The existing style gauges ([RacingGauge], [NeonRingGauge], ...) take an
/// unsigned percent and fill from the scale start, so they cannot express
/// center-zero semantics on their own. Each branch below mirrors one
/// style's card, typography and geometry instead of inventing a separate
/// visual system; the classic 'cards' style keeps using [VoltageDeltaCard]
/// with the original [DeltaGauge].
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

  /// The signed difference to display; null renders an empty track.
  final double? delta;

  final String label;

  final String unit;

  /// Full-scale magnitude (both directions), in [unit]s.
  final double scale;

  final VoidCallback? onTap;

  /// Signed fill fraction in [-1, 1]; 0 while [delta] is null.
  double get _fraction {
    final value = delta;
    if (value == null) return 0;
    return (value / scale).clamp(-1.0, 1.0);
  }

  bool get _isEmpty => delta == null || delta!.abs() < 0.005;

  Color get _accent {
    final value = delta;
    if (value == null || value.abs() < 0.005) return AppColors.neonCyan;
    return value > 0 ? AppColors.neonGreen : AppColors.neonRed;
  }

  /// Signed fill color: green to the right, red to the left.
  Color get _fillColor {
    final value = delta;
    if (value == null) return AppColors.neonCyan;
    return value >= 0 ? AppColors.neonGreen : AppColors.neonRed;
  }

  String get _valueText {
    final value = delta;
    if (value == null) return '--.- $unit';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)} $unit';
  }

  /// Signed number without the unit, for the center of the round gauges.
  String get _signedNumber {
    final value = delta;
    if (value == null) return '--.-';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
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
  // racing — big number over a gradient bar (see RacingGauge), here the
  // bar starts at the central zero and grows to either side.
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
  // sporty — analog dial with needle (see SportyGauge), here the dial
  // spans -scale .. +scale with the zero at the top.
  // ------------------------------------------------------------------
  Widget _buildSporty(BuildContext context) {
    return _shell(context,
      children: [
        CustomPaint(
          size: const Size(170, 170),
          painter: _SportyDeltaPainter(
            fraction: _fraction,
            scale: scale,
            // Null hides the needle (empty); a real ~zero reading keeps a
            // neutral cyan needle pointing at the central zero.
            empty: delta == null,
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
  // segments — 12 blocks (see SegmentedGauge), here filling outward from
  // the central zero: upper half green, lower half red.
  // ------------------------------------------------------------------
  Widget _buildSegments(BuildContext context) {
    const blocks = 12;
    const half = blocks ~/ 2;

    final lit = (_fraction.abs() * half).round();
    final positive = _fraction >= 0;

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
            // Index 0 is the bottom block, like SegmentedGauge: blocks
            // 0-5 sit below the zero line (red side), 6-11 above (green).
            verticalDirection: VerticalDirection.up,
            children: List.generate(blocks, (index) {
              final bool active;
              if (_isEmpty || lit == 0) {
                active = false;
              } else if (positive) {
                active = index >= half && index < half + lit;
              } else {
                active = index < half && index >= half - lit;
              }

              final color = positive ? AppColors.neonGreen : AppColors.neonRed;

              return Container(
                height: 7,
                margin: const EdgeInsets.symmetric(vertical: 0.75),
                decoration: BoxDecoration(
                  color: active
                      ? color
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
  // sweeper — trapezoid sweep (see AudiSweeperGauge), here sweeping from
  // the central zero to the right (green) or to the left (red).
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
            painter: _SweeperDeltaPainter(
              fraction: _fraction,
              color: _fillColor,
            ),
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
  // ring — smartwatch progress ring (see NeonRingGauge), here sweeping
  // from the top-zero clockwise (green) or counter-clockwise (red).
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
                  color: _fillColor,
                  empty: _isEmpty,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _signedNumber,
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
  // led — 20 glowing blocks (see LedStripGauge), here lighting outward
  // from the central zero: green to the right, red to the left.
  // ------------------------------------------------------------------
  Widget _buildLed(BuildContext context) {
    const blocks = 20;
    const half = blocks ~/ 2;

    final lit = (_fraction.abs() * half).round();
    final positive = _fraction >= 0;

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
        // The strip is signed (left = negative): keep blocks in canvas
        // order even in RTL locales.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: List.generate(blocks, (index) {
              final bool litBlock;
              if (_isEmpty || lit == 0) {
                litBlock = false;
              } else if (positive) {
                litBlock = index >= half && index < half + lit;
              } else {
                litBlock = index < half && index >= half - lit;
              }

              final color = _fillColor;

              return Expanded(
                child: Container(
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: litBlock
                        ? color
                        : Colors.white.withAlpha((255 * 0.07).round()),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: litBlock
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
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // needle — VU-style meter (see NeedleMeterGauge), here the needle rests
  // at the central zero and swings right (green) or left (red).
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
              color: _fillColor,
              // Null renders an empty meter (no needle), like every other
              // style: only zones, ticks and the pivot remain.
              empty: delta == null,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // orb — liquid orb (see LiquidOrbGauge), here the liquid rises above
  // the central zero line (green) or below it (red).
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
                  color: _fillColor,
                  empty: _isEmpty,
                ),
              ),
              Center(
                child: Text(
                  '$_signedNumber\n$unit',
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
  // combo — 260° cluster ring with lit dots (see DigitalClusterGauge),
  // here lighting from the top-zero clockwise (green) or
  // counter-clockwise (red).
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
                  color: _fillColor,
                  empty: _isEmpty,
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _signedNumber,
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
// Painters — signed, center-zero adaptations of the style painters in
// dashboard_gauges.dart / more_gauges.dart.
// ======================================================================

/// racing bar: track + central zero line + gradient fill from the center.
class _RacingDeltaPainter extends CustomPainter {
  _RacingDeltaPainter({required this.fraction});

  /// Signed fraction in [-1, 1].
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

    final center = w / 2;
    final reach = (w / 2 - 2);

    if (fraction.abs() > 0.003) {
      final x = center + fraction * reach;
      final fill = Rect.fromLTRB(
        math.min(center, x),
        1,
        math.max(center, x),
        size.height - 2,
      );

      final positive = fraction > 0;
      final colors = positive
          ? const [AppColors.neonCyan, AppColors.neonGreen]
          : const [AppColors.neonAmber, AppColors.neonRed];

      canvas.save();
      canvas.clipRRect(barRect);
      canvas.drawRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: positive ? Alignment.centerLeft : Alignment.centerRight,
            end: positive ? Alignment.centerRight : Alignment.centerLeft,
            colors: colors,
          ).createShader(fill),
      );
      canvas.restore();
    }

    // Central zero line.
    canvas.drawLine(
      Offset(center, -1),
      Offset(center, size.height + 1),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withAlpha((255 * 0.55).round()),
    );
  }

  @override
  bool shouldRepaint(_RacingDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// sporty dial: 240° face from -scale to +scale, zero at the top.
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

    // Signed value mapped onto the dial: -1 .. 0 .. +1 -> start .. middle .. end.
    final pct = (fraction + 1) / 2;
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

    // Negative half (left of zero) red zone, positive half green zone.
    for (final (from, to, color) in [
      (0.0, 0.5, AppColors.neonRed.withAlpha((255 * 0.18).round())),
      (0.5, 1.0, AppColors.neonGreen.withAlpha((255 * 0.18).round())),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start + from * range,
        (to - from) * range,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = color,
      );
    }

    // Ticks and scale numbers: -scale, -scale/2, 0, +scale/2, +scale.
    const steps = 4;
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final a = start + f * range;

      final isZero = i == steps ~/ 2;

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

      final value = -scale + f * 2 * scale;
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

    // Needle resting at the central zero when the value is zero.
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

/// sweeper trapezoid: filled from the central zero to either side.
class _SweeperDeltaPainter extends CustomPainter {
  _SweeperDeltaPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  /// Same slanted-sides trapezoid as the Audi sweeper, over [x0, x1].
  Path _trapezoid(double w, double h, double x0, double x1) {
    const slant = 18.0;

    return Path()
      ..moveTo(x0, h)
      ..lineTo(x0 + slant, 5)
      ..lineTo(x1, 5)
      ..lineTo(math.max(x0, x1 - slant), h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (w < 40 || h <= 0) return;

    final full = _trapezoid(w, h, 0, w);

    canvas.drawPath(
      full,
      Paint()..color = Colors.white.withAlpha((255 * 0.03).round()),
    );

    final center = w / 2;

    if (fraction.abs() > 0.003) {
      final x = center + fraction * (w / 2 - 18);
      final fill = _trapezoid(
        w,
        h,
        math.min(center, x),
        math.max(center, x),
      );

      final positive = fraction > 0;

      canvas.save();
      canvas.clipPath(fill);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = LinearGradient(
            begin: positive ? Alignment.centerLeft : Alignment.centerRight,
            end: positive ? Alignment.centerRight : Alignment.centerLeft,
            colors: [color.withAlpha(80), color],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      canvas.restore();
    }

    canvas.drawPath(
      full,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withAlpha((255 * 0.06).round()),
    );

    // Central zero line.
    canvas.drawLine(
      Offset(center, 2),
      Offset(center, h),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withAlpha((255 * 0.45).round()),
    );
  }

  @override
  bool shouldRepaint(_SweeperDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// neon ring: value sweeps from the top-zero clockwise (+, green) or
/// counter-clockwise (-, red).
class _RingDeltaPainter extends CustomPainter {
  _RingDeltaPainter({
    required this.fraction,
    required this.color,
    required this.empty,
  });

  final double fraction;
  final Color color;
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

    // Zero marker at the top of the ring.
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 11),
      Offset(center.dx, center.dy - radius + 11),
      Paint()
        ..strokeWidth = 2.5
        ..color = Colors.white.withAlpha((255 * 0.7).round()),
    );

    if (empty || fraction.abs() < 0.003) return;

    // Half the circle is one sign's full scale.
    final sweep = fraction.abs() * math.pi;
    final from = fraction > 0 ? start : start - sweep;

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 11
          ..color = color;

    canvas.drawArc(rect, from, sweep, false, paint);

    final knobAngle = fraction > 0 ? start + sweep : start - sweep;

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
      oldDelegate.fraction != fraction ||
      oldDelegate.empty != empty ||
      oldDelegate.color != color;
}

/// VU needle: -50°..+50° around the central zero.
class _NeedleDeltaPainter extends CustomPainter {
  _NeedleDeltaPainter({
    required this.fraction,
    required this.color,
    required this.empty,
  });

  final double fraction;
  final Color color;
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

    // Negative half (left) dim red, positive half (right) dim green.
    final zones = [
      (-_sweepDeg / 2, 0.0, AppColors.neonRed.withAlpha((255 * 0.20).round())),
      (0.0, _sweepDeg / 2, AppColors.neonGreen.withAlpha((255 * 0.20).round())),
    ];

    for (final (fromDeg, toDeg, color) in zones) {
      canvas.drawArc(
        zoneRect,
        (fromDeg - 90) * math.pi / 180,
        (toDeg - fromDeg) * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    // Ticks; the central one marks the zero.
    for (var i = 0; i <= 10; i++) {
      final deg = -_sweepDeg / 2 + (i / 10) * _sweepDeg;
      final isZero = i == 5;

      canvas.drawLine(
        point(deg, radius - (isZero ? 7 : 4)),
        point(deg, radius + 4),
        Paint()
          ..strokeWidth = isZero ? 2.5 : 1.5
          ..color = Colors.white.withAlpha((255 * (isZero ? 0.9 : 0.5)).round()),
      );
    }

    // Needle swings from the central zero; omitted entirely while there is
    // no reading so null renders an empty track like the other styles.
    if (!empty) {
      final needleDeg = (fraction / 2) * _sweepDeg;
      final tip = point(needleDeg, radius - 10);

      canvas.drawLine(
        pivot,
        tip,
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color,
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
      oldDelegate.color != color;
}

/// liquid orb: wavy liquid above (+, green) or below (-, red) the
/// central zero line.
class _OrbDeltaPainter extends CustomPainter {
  _OrbDeltaPainter({
    required this.fraction,
    required this.color,
    required this.empty,
  });

  final double fraction;
  final Color color;
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

    if (!empty && fraction.abs() > 0.003) {
      // Liquid surface sits fraction * radius away from the zero line.
      final surfaceY = center.dy - fraction * radius;

      final top = math.min(center.dy, surfaceY);
      final bottom = math.max(center.dy, surfaceY);

      final wave = Path()
        ..moveTo(center.dx - radius, top)
        ..cubicTo(
          center.dx - radius / 2,
          top - 6,
          center.dx,
          top + 6,
          center.dx + radius / 2,
          top,
        )
        ..cubicTo(
          center.dx + radius * 0.85,
          top - 4,
          center.dx + radius,
          top,
          center.dx + radius,
          top,
        )
        ..lineTo(center.dx + radius, bottom)
        ..lineTo(center.dx - radius, bottom)
        ..close();

      canvas.drawPath(
        wave,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(0x99), color.withAlpha(0xCC)],
          ).createShader(orbRect),
      );

      // Bubbles inside the liquid.
      final bubblePaint = Paint()..color = Colors.white.withAlpha(60);
      canvas.drawCircle(
        center.translate(-radius * 0.3, (top + bottom) / 2 - center.dy),
        3,
        bubblePaint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.25, (top + bottom) / 2 - center.dy * 0.9),
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

    // Central zero line.
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      Paint()
        ..strokeWidth = 1.5
        ..color = Colors.white.withAlpha((255 * 0.4).round()),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.empty != empty ||
      oldDelegate.color != color;
}

/// digital cluster: 260° arc + dots lighting from the top-zero clockwise
/// (+, green) or counter-clockwise (-, red).
class _ClusterDeltaPainter extends CustomPainter {
  _ClusterDeltaPainter({
    required this.fraction,
    required this.color,
    required this.empty,
  });

  final double fraction;
  final Color color;
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
    final zeroAngle = start + sweep / 2;

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

    // Dots along the arc; lit dots radiate from the central zero.
    const dots = 14;

    for (var i = 0; i <= dots; i++) {
      final f = i / dots;
      final angle = start + f * sweep;

      final dotPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final signedF = (f - 0.5) * 2; // -1 .. 0 .. +1

      final lit = !empty &&
          ((fraction > 0 && signedF > 0 && signedF <= fraction) ||
              (fraction < 0 && signedF < 0 && -signedF <= -fraction));

      final isZero = i == dots ~/ 2;

      canvas.drawCircle(
        dotPos,
        lit ? 3.4 : (isZero ? 3.4 : 2.2),
        Paint()
          ..color = lit
              ? color
              : isZero
              ? Colors.white.withAlpha((255 * 0.6).round())
              : Colors.white.withAlpha((255 * 0.14).round()),
      );
    }

    // Main arc from the central zero toward the value.
    if (!empty && fraction.abs() > 0.003) {
      final arcSweep = fraction.abs() * sweep / 2;
      final arcStart = fraction > 0 ? zeroAngle : zeroAngle - arcSweep;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 11),
        arcStart,
        arcSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ClusterDeltaPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.empty != empty ||
      oldDelegate.color != color;
}
