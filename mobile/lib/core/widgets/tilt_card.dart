import 'package:flutter/material.dart';

/// Wraps [child] in a `Transform`-based 3D tilt that follows a drag/pointer
/// gesture and springs back to flat on release — this branch's task calls
/// for "a subtle Transform-based tilt on the brand-kit logo preview card"
/// specifically, and this is generic enough to reuse anywhere else a card
/// wants the same touch (nothing else uses it yet).
///
/// [onTap] is handled by this widget's own `GestureDetector` rather than
/// requiring a separate wrapper — combining a tap recognizer with pan
/// recognizers on one `GestureDetector` is a standard, supported Flutter
/// combination (a still tap resolves as a tap; movement past touch slop
/// resolves as a pan instead), so there's no gesture-arena conflict from
/// merging both here.
///
/// Uses `TweenAnimationBuilder` rather than a hand-rolled
/// `AnimationController` — `_tilt`'s target simply changes on every drag
/// update and again on release, and `TweenAnimationBuilder` already
/// animates smoothly between whatever `end` value it's given across
/// rebuilds, which is exactly this widget's whole state machine. A faster
/// duration while actively dragging (snappy, feels directly driven) and a
/// slower one on release (a soft spring-back) are both just different
/// `duration` values passed to the same builder.
class TiltCard extends StatefulWidget {
  const TiltCard({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  static const _maxTiltRadians = 0.18;
  static const _dragDuration = Duration(milliseconds: 80);
  static const _releaseDuration = Duration(milliseconds: 350);

  Offset _tilt = Offset.zero;
  bool _isDragging = false;

  void _updateTilt(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = ((localPosition.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((localPosition.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    setState(() => _tilt = Offset(dx, dy));
  }

  void _resetTilt() {
    setState(() {
      _isDragging = false;
      _tilt = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTap: widget.onTap,
          onPanDown: (_) => setState(() => _isDragging = true),
          onPanUpdate: (details) => _updateTilt(details.localPosition, size),
          onPanEnd: (_) => _resetTilt(),
          onPanCancel: _resetTilt,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(end: _tilt),
            duration: _isDragging ? _dragDuration : _releaseDuration,
            curve: Curves.easeOut,
            builder: (context, tilt, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-tilt.dy * _maxTiltRadians)
                  ..rotateY(tilt.dx * _maxTiltRadians),
                child: child,
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}
