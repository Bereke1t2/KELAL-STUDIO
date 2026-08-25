import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Spinner-style loading indicator — Figma `Components / Loading
/// Indicator`, node `27:2` ("Type=Spinner, Size=Default"): a 32px
/// spinner with an optional caption below it (e.g. "Generating caption…
/// (3s target)"), used for the generation-in-progress state. The file
/// also documents a separate `Components / Skeleton Loader` pattern
/// (node `44:2`, content-shaped placeholder rectangles for
/// caption/graphic/drafts-grid) for list/content loading — out of scope
/// here since the task asked for "a loading indicator," but flagged for
/// whichever branch builds the drafts list or generation-result screens.
///
/// The Figma spinner is a static rotating-arc icon asset; Flutter's
/// [CircularProgressIndicator] is used in its place (animated, and this
/// codebase has no SVG asset pipeline — see the note in
/// `flutter-design-system/SKILL.md`) rather than committing a
/// hand-drawn approximation of the icon's vector path.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({this.caption, this.size = 32, this.value, super.key});

  /// Optional status text shown below the spinner, e.g. "Generating
  /// caption… (3s target)".
  final String? caption;

  /// Spinner diameter. Defaults to the Figma "Default" size (32px).
  final double size;

  /// Forwarded to [CircularProgressIndicator.value]. Left `null` (the
  /// indeterminate, continuously-animating spinner) for real usage,
  /// matching Figma's spinner intent — exposed mainly so golden tests can
  /// pin a fixed, non-animating frame instead of hanging `pumpAndSettle`
  /// on a never-settling animation.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primaryDefault,
            value: value,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption!,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
