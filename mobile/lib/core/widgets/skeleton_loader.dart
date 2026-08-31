import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// A single placeholder block for a skeleton-loading layout — a rounded
/// rect that pulses opacity in a loop (a repeating, reversing
/// `AnimationController`) rather than the flat static gray boxes this app
/// used before, or a real `CircularProgressIndicator` spinner.
///
/// Deliberately an opacity pulse, not a shimmer-gradient sweep: a sweep
/// needs a `ShaderMask`/`LinearGradient` animated across each box, which
/// only reads cleanly at a fixed box size known ahead of time — this
/// widget is used at several different sizes (a full-width list-item row,
/// a form-field-height bar), and a per-box independent pulse looks
/// coherent at any of them without extra plumbing to synchronize a
/// shared sweep phase across multiple `SkeletonBox`es. `flutter_animate`/
/// `shimmer` aren't added for this — see mobile/CLAUDE.md's "don't add a
/// dependency unless confirmed genuinely unavailable" rule.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
    super.key,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.bgDisabled,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}
