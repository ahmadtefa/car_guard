import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';

/// The three newer dashboard styles are kept in one file so their visual
/// systems remain independent from the established gauges. None of these
/// widgets uses [MiniArcGauge] or [BaseDashboardCard]: each style owns its
/// painter and its responsive four-reading composition.

class RoseDashboardStyle extends StatelessWidget {
  const RoseDashboardStyle({
    super.key,
    required this.temperatureLabel,
    required this.voltageLabel,
    required this.speedLabel,
    required this.distanceLabel,
    required this.temperature,
    required this.voltageDelta,
    required this.speed,
    required this.distance,
    required this.hasFix,
    required this.onTemperatureTap,
  });

  final String temperatureLabel;
  final String voltageLabel;
  final String speedLabel;
  final String distanceLabel;
  final double temperature;
  final double? voltageDelta;
  final double speed;
  final double distance;
  final bool hasFix;
  final VoidCallback onTemperatureTap;

  @override
  Widget build(BuildContext context) {
    final delta = voltageDelta?.abs();

    return _StyleGrid(
      first: _RoseReading(
        label: temperatureLabel,
        value: '${temperature.toStringAsFixed(1)} °C',
        progress: (temperature / 180).clamp(0.0, 1.0).toDouble(),
        accent: const Color(0xFFE56B91),
        onTap: onTemperatureTap,
      ),
      second: _RoseReading(
        label: voltageLabel,
        value: delta == null ? '--.- V' : '${delta.toStringAsFixed(2)} V',
        progress: ((delta ?? 0) / 1.5).clamp(0.0, 1.0).toDouble(),
        accent: const Color(0xFFB84F86),
      ),
      third: _RoseTripReading(
        label: speedLabel,
        value: hasFix ? '${speed.toStringAsFixed(0)} km/h' : '-- km/h',
        progress: (speed / 180).clamp(0.0, 1.0).toDouble(),
      ),
      fourth: _RoseTripReading(
        label: distanceLabel,
        value: hasFix ? '${distance.toStringAsFixed(2)} km' : '-- km',
        progress: (distance / 20).clamp(0.0, 1.0).toDouble(),
      ),
    );
  }
}

class LavenderDashboardStyle extends StatelessWidget {
  const LavenderDashboardStyle({
    super.key,
    required this.temperatureLabel,
    required this.voltageLabel,
    required this.speedLabel,
    required this.distanceLabel,
    required this.temperature,
    required this.voltageDelta,
    required this.speed,
    required this.distance,
    required this.hasFix,
    required this.onTemperatureTap,
  });

  final String temperatureLabel;
  final String voltageLabel;
  final String speedLabel;
  final String distanceLabel;
  final double temperature;
  final double? voltageDelta;
  final double speed;
  final double distance;
  final bool hasFix;
  final VoidCallback onTemperatureTap;

  @override
  Widget build(BuildContext context) {
    final delta = voltageDelta?.abs();

    return _StyleGrid(
      first: _LavenderReading(
        label: temperatureLabel,
        value: '${temperature.toStringAsFixed(1)} °C',
        progress: (temperature / 180).clamp(0.0, 1.0).toDouble(),
        accent: const Color(0xFFA889E8),
        onTap: onTemperatureTap,
      ),
      second: _LavenderReading(
        label: voltageLabel,
        value: delta == null ? '--.- V' : '${delta.toStringAsFixed(2)} V',
        progress: ((delta ?? 0) / 1.5).clamp(0.0, 1.0).toDouble(),
        accent: const Color(0xFF8E72C8),
      ),
      third: _LavenderTripReading(
        label: speedLabel,
        value: hasFix ? '${speed.toStringAsFixed(0)} km/h' : '-- km/h',
        progress: (speed / 180).clamp(0.0, 1.0).toDouble(),
      ),
      fourth: _LavenderTripReading(
        label: distanceLabel,
        value: hasFix ? '${distance.toStringAsFixed(2)} km' : '-- km',
        progress: (distance / 20).clamp(0.0, 1.0).toDouble(),
      ),
    );
  }
}

/// A flamingo is drawn as the main gauge surface. The temperature and voltage
/// readings sit in the bird's two wing panels, while the lower row keeps speed
/// and distance readable without hiding the illustration.
class FlamingoDashboardStyle extends StatelessWidget {
  const FlamingoDashboardStyle({
    super.key,
    required this.temperatureLabel,
    required this.voltageLabel,
    required this.speedLabel,
    required this.distanceLabel,
    required this.temperature,
    required this.voltageDelta,
    required this.speed,
    required this.distance,
    required this.hasFix,
  });

  final String temperatureLabel;
  final String voltageLabel;
  final String speedLabel;
  final String distanceLabel;
  final double temperature;
  final double? voltageDelta;
  final double speed;
  final double distance;
  final bool hasFix;

  @override
  Widget build(BuildContext context) {
    final delta = voltageDelta?.abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FlamingoPrimaryVisual(
          temperatureLabel: temperatureLabel,
          voltageLabel: voltageLabel,
          temperature: temperature,
          voltageDelta: delta,
        ),
        const SizedBox(height: AppSpacing.md),
        _StyleGrid(
          first: _FlamingoTripReading(
            label: speedLabel,
            value: hasFix ? '${speed.toStringAsFixed(0)} km/h' : '-- km/h',
            progress: (speed / 180).clamp(0.0, 1.0).toDouble(),
          ),
          second: _FlamingoTripReading(
            label: distanceLabel,
            value: hasFix ? '${distance.toStringAsFixed(2)} km' : '-- km',
            progress: (distance / 20).clamp(0.0, 1.0).toDouble(),
          ),
          third: const SizedBox.shrink(),
          fourth: const SizedBox.shrink(),
          hideSecondRow: true,
        ),
      ],
    );
  }
}

class _StyleGrid extends StatelessWidget {
  const _StyleGrid({
    required this.first,
    required this.second,
    required this.third,
    required this.fourth,
    this.hideSecondRow = false,
  });

  final Widget first;
  final Widget second;
  final Widget third;
  final Widget fourth;
  final bool hideSecondRow;

  static const double _sideBySideBreakpoint = 316;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.hasBoundedWidth &&
            constraints.maxWidth >= _sideBySideBreakpoint;

        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.md),
              second,
              if (!hideSecondRow) ...[
                const SizedBox(height: AppSpacing.md),
                third,
                const SizedBox(height: AppSpacing.md),
                fourth,
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: second),
              ],
            ),
            if (!hideSecondRow) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: third),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: fourth),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RoseReading extends StatelessWidget {
  const _RoseReading({
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final double progress;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF6F9), Color(0xFFFFE7EF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withAlpha(100)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FE56B91),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4D2638),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 58,
            child: CustomPaint(
              painter: _RoseArcPainter(
                progress: progress,
                accent: accent,
              ),
            ),
          ),
        ],
      ),
    );

    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}

class _RoseTripReading extends StatelessWidget {
  const _RoseTripReading({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9A5B8)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9B5470),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4D2638),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 18,
            child: CustomPaint(
              painter: _RoseTripPainter(progress: progress),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoseArcPainter extends CustomPainter {
  const _RoseArcPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 8);
    final radius = math.min(size.width * 0.35, size.height * 1.25);
    const start = math.pi * 1.15;
    const sweep = math.pi * 0.7;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = accent.withAlpha(45);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = accent;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress.clamp(0.0, 1.0),
      false,
      active,
    );

    final angle = start + sweep * progress.clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
      5,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_RoseArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _RoseTripPainter extends CustomPainter {
  const _RoseTripPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final start = Offset(2, y);
    final end = Offset(size.width - 2, y);
    final track = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x33D56D93);
    final active = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD56D93);

    canvas.drawLine(start, end, track);
    canvas.drawLine(
      start,
      Offset(start.dx + (end.dx - start.dx) * progress.clamp(0.0, 1.0), y),
      active,
    );

    for (var i = 0; i < 5; i++) {
      final x = 2 + (size.width - 4) * i / 4;
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = const Color(0xFFF4B7C8));
    }
  }

  @override
  bool shouldRepaint(_RoseTripPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LavenderReading extends StatelessWidget {
  const _LavenderReading({
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final double progress;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFCFAFF), Color(0xFFEDE5FC)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7C8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C8E72C8),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF302647),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: _LavenderGaugePainter(
                progress: progress,
                accent: accent,
              ),
            ),
          ),
        ],
      ),
    );

    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}

class _LavenderTripReading extends StatelessWidget {
  const _LavenderTripReading({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7C8F2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF806EA9),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF302647),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: CustomPaint(
              painter: _LavenderPearlsPainter(progress: progress),
            ),
          ),
        ],
      ),
    );
  }
}

class _LavenderGaugePainter extends CustomPainter {
  const _LavenderGaugePainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final outer = math.min(size.width, size.height) * 0.36;
    final inner = outer * 0.7;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x339078C8);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = accent;

    canvas.drawCircle(center, outer, track);
    canvas.drawCircle(center, inner, track..strokeWidth = 2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outer),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      active,
    );

    final angle = -math.pi / 2 + math.pi * 2 * progress.clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(center.dx + outer * math.cos(angle), center.dy + outer * math.sin(angle)),
      5,
      Paint()..color = accent,
    );
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF6D579D));
  }

  @override
  bool shouldRepaint(_LavenderGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _LavenderPearlsPainter extends CustomPainter {
  const _LavenderPearlsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 8;
    final step = size.width / count;
    final activeCount = (progress.clamp(0.0, 1.0) * count).round();

    for (var i = 0; i < count; i++) {
      final center = Offset(step * (i + 0.5), size.height / 2);
      final isActive = i < activeCount;
      canvas.drawCircle(
        center,
        7,
        Paint()..color = isActive
            ? const Color(0xFFAD92E7)
            : const Color(0xFFE3DAF4),
      );
      if (isActive) {
        canvas.drawCircle(
          center.translate(-2, -2),
          2,
          Paint()..color = Colors.white.withAlpha(190),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LavenderPearlsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FlamingoPrimaryVisual extends StatelessWidget {
  const _FlamingoPrimaryVisual({
    required this.temperatureLabel,
    required this.voltageLabel,
    required this.temperature,
    required this.voltageDelta,
  });

  final String temperatureLabel;
  final String voltageLabel;
  final double temperature;
  final double? voltageDelta;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 340 ? 232.0 : 260.0;

        return Container(
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF321A31), Color(0xFF120D1F)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFF7FA8).withAlpha(150)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3DFF5C91),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FlamingoPainter(
                    temperatureProgress:
                        (temperature / 180).clamp(0.0, 1.0).toDouble(),
                    voltageProgress:
                        ((voltageDelta ?? 0) / 1.5).clamp(0.0, 1.0).toDouble(),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FlamingoMetric(
                        label: temperatureLabel,
                        value: '${temperature.toStringAsFixed(1)} °C',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FlamingoMetric(
                        label: voltageLabel,
                        value: voltageDelta == null
                            ? '--.- V'
                            : '${voltageDelta!.toStringAsFixed(2)} V',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlamingoMetric extends StatelessWidget {
  const _FlamingoMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC170F20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9FBD).withAlpha(180)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFB5CA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlamingoTripReading extends StatelessWidget {
  const _FlamingoTripReading({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF24152B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF7FA8).withAlpha(130)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFA5BF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: CustomPaint(
              painter: _FlamingoFeatherPainter(progress: progress),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlamingoPainter extends CustomPainter {
  const _FlamingoPainter({
    required this.temperatureProgress,
    required this.voltageProgress,
  });

  final double temperatureProgress;
  final double voltageProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 420, size.height / 280);
    final dx = (size.width - 420 * scale) / 2;
    final dy = (size.height - 280 * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final water = Paint()
      ..color = const Color(0x66FF9FBD)
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final y = 238.0 + i * 8;
      canvas.drawLine(Offset(34, y), Offset(386, y), water);
    }

    final body = Paint()..color = const Color(0xFFFF769F);
    final shadow = Paint()..color = const Color(0xFFCF4F83);
    final highlight = const Color(0xFFFFB4C8);

    // The long neck and head are the centre of the gauge, not a detached icon.
    final neck = Path()
      ..moveTo(228, 199)
      ..cubicTo(197, 166, 171, 137, 175, 93)
      ..cubicTo(179, 59, 166, 42, 148, 38);
    canvas.drawPath(
      neck,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..color = body.color,
    );
    canvas.drawPath(
      neck,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = highlight,
    );

    canvas.drawCircle(const Offset(140, 34), 19, body);
    final beak = Path()
      ..moveTo(124, 34)
      ..lineTo(91, 42)
      ..lineTo(122, 48)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFF24202E));
    canvas.drawCircle(const Offset(145, 29), 3, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(145, 29), 1.5, Paint()..color = const Color(0xFF302033));

    final bodyRect = Rect.fromCenter(
      center: const Offset(250, 190),
      width: 172,
      height: 83,
    );
    canvas.drawOval(bodyRect, body);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(268, 193), width: 114, height: 58),
      shadow,
    );

    final wing = Path()
      ..moveTo(193, 187)
      ..cubicTo(218, 151, 275, 151, 316, 183)
      ..cubicTo(285, 217, 228, 220, 193, 187)
      ..close();
    canvas.drawPath(wing, Paint()..color = const Color(0xFFE65F8C));
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(245 + i * 12, 188 + i * 3),
          width: 70 - i * 8,
          height: 38 - i * 3,
        ),
        0.15,
        2.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = highlight.withAlpha(170),
      );
    }

    // Two gauge arcs are embedded in the bird's body beneath the wing panels.
    _drawGaugeArc(
      canvas,
      const Offset(124, 193),
      34,
      temperatureProgress,
      const Color(0xFFFFC1D2),
    );
    _drawGaugeArc(
      canvas,
      const Offset(348, 193),
      34,
      voltageProgress,
      const Color(0xFFFF9FBD),
    );

    final legs = Paint()
      ..color = const Color(0xFFFFB4C8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(240, 225), const Offset(233, 252), legs);
    canvas.drawLine(const Offset(286, 224), const Offset(294, 252), legs);
    canvas.drawLine(const Offset(228, 252), const Offset(241, 252), legs);
    canvas.drawLine(const Offset(289, 252), const Offset(302, 252), legs);

    canvas.restore();
  }

  void _drawGaugeArc(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    Color color,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      math.pi * 0.8,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = color.withAlpha(70),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.8,
      math.pi * 1.4 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FlamingoPainter oldDelegate) =>
      oldDelegate.temperatureProgress != temperatureProgress ||
      oldDelegate.voltageProgress != voltageProgress;
}

class _FlamingoFeatherPainter extends CustomPainter {
  const _FlamingoFeatherPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()..moveTo(2, y);
    for (var i = 0; i < 7; i++) {
      final x = 2 + (size.width - 4) * i / 6;
      path.lineTo(x, y + (i.isEven ? -5 : 5));
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF8EAF).withAlpha(70),
    );
    canvas.drawLine(
      const Offset(2, 0),
      Offset(2 + (size.width - 4) * progress.clamp(0.0, 1.0), 0),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF8EAF),
    );
  }

  @override
  bool shouldRepaint(_FlamingoFeatherPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
