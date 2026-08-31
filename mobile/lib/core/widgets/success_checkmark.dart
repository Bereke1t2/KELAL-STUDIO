import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small "drawn-in" checkmark — the circle outline strokes in first, then
/// the check strokes in on top — used as the leading visual on a success
/// snack bar (`ExportPage`'s save-to-gallery confirmation). Built on
/// `CustomPainter`/`AnimationController` rather than a static [Icons.check]
/// glyph, per this branch's task ("export success micro-interaction"); no
/// new dependency (no `lottie`/`rive`) since two `Path`s and a
/// `PathMetric`-driven stroke reveal don't need one.
class SuccessCheckmark extends StatefulWidget {
  const SuccessCheckmark({required this.color, this.size = 24, super.key});

  final double size;

  /// Required rather than defaulted — this widget is always embedded in a
  /// caller-themed context (e.g. a colored snack bar), and there's no
  /// single default that would read correctly against every background it
  /// could be placed on. An earlier version defaulted to
  /// `DefaultTextStyle.of(context).style.color!`, which force-unwraps a
  /// value that's `null` by default in plenty of real widget contexts —
  /// removed as a real crash risk rather than kept as a convenience.
  final Color color;

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _CheckmarkPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

/// Draws the circle outline over the animation's first 60% and the check
/// mark over the remaining 40% — sequential, not simultaneous, so the
/// checkmark visibly "lands inside" a shape that's already forming rather
/// than both strokes racing each other.
class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _circlePhaseEnd = 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - paint.strokeWidth / 2;

    final circleProgress = (progress / _circlePhaseEnd).clamp(0.0, 1.0);
    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        paint,
      );
    }

    final checkProgress = ((progress - _circlePhaseEnd) / (1 - _circlePhaseEnd))
        .clamp(0.0, 1.0);
    if (checkProgress > 0) {
      final checkPath = Path()
        ..moveTo(size.width * 0.28, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.68)
        ..lineTo(size.width * 0.74, size.height * 0.34);
      final metric = checkPath.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkProgress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
