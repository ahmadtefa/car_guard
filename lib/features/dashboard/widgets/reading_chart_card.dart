import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Card that renders a reading series as a lightweight sparkline using a
/// [CustomPainter] — no chart dependency required.
class ReadingChartCard extends StatelessWidget {
  const ReadingChartCard({
    super.key,
    required this.title,
    required this.values,
    required this.unit,
    this.color = AppColors.primary,
    this.subtitle = 'Last 5 minutes',
  });

  final String title;

  /// Chronological readings; may be empty until data arrives.
  final List<double> values;

  final String unit;
  final Color color;
  final String subtitle;

  String get _currentLabel {
    if (values.isEmpty) return '-- $unit';

    return '${values.last.toStringAsFixed(1)} $unit';
  }

  String get _rangeLabel {
    if (values.length < 2) return 'Collecting data...';

    final min = values.reduce(math.min);
    final max = values.reduce(math.max);

    return '${min.toStringAsFixed(1)} – ${max.toStringAsFixed(1)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _currentLabel,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              '$subtitle • $_rangeLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(values: values, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);

    final range = (maxValue - minValue) == 0 ? 1.0 : maxValue - minValue;
    final stepX = size.width / (values.length - 1);

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - ((values[i] - minValue) / range) * size.height;

      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final linePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

    canvas.drawPath(line, linePaint);

    final fill =
        Path.from(line)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withAlpha((255 * 0.15).round())
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
