import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Icon that continuously rotates while [spinning] is true and freezes in
/// place otherwise — used for the fan blade and alternator gear.
class SpinningIcon extends StatefulWidget {
  const SpinningIcon({
    super.key,
    required this.icon,
    required this.spinning,
    this.duration = const Duration(milliseconds: 600),
    this.size = 28,
    this.color,
  });

  final IconData icon;
  final bool spinning;
  final Duration duration;
  final double size;
  final Color? color;

  @override
  State<SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();

    if (widget.spinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpinningIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: widget.spinning ? _controller.value * 2 * math.pi : 0,
          child: child,
        );
      },
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}
