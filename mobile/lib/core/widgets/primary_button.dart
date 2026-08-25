import 'package:flutter/material.dart';

/// The app's primary call-to-action button — Figma `Components / Button`,
/// node `14:2` ("Style=Primary, State=Default"). Visual styling (fill
/// color, radius, min tap target, label typography) already lives on
/// [ElevatedButtonThemeData] in `core/theme/app_theme.dart`, pulled from
/// the same node, so this widget is a thin behavioral wrapper: it adds the
/// `isLoading` swap every submit-style action in this app needs.
///
/// [isLoading] disables the button and swaps its label for a small
/// spinner in the same slot — this is a direct extraction of the pattern
/// `LoginPage` hand-rolled before this widget existed (see
/// `features/auth/presentation/pages/login_page.dart`); the swap visuals
/// are preserved exactly (20x20, strokeWidth 2, no explicit color
/// override) rather than "improved" silently, since that would change
/// pixel output out from under the existing golden/widget test coverage.
/// Note: the default `CircularProgressIndicator` color resolves to
/// `ColorScheme.primary`, which is the same color as this button's own
/// fill — on a real device the spinner may read as nearly invisible
/// against the button background. This is a pre-existing behavior being
/// preserved, not introduced here; flagged for a follow-up rather than
/// changed silently under a "design system foundation" branch.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingValue,
    super.key,
  });

  /// Button text, shown when [isLoading] is false.
  final String label;

  /// Tapped when enabled and not loading. Passing `null` disables the
  /// button regardless of [isLoading].
  final VoidCallback? onPressed;

  /// When true, the button is disabled and shows a small spinner instead
  /// of [label].
  final bool isLoading;

  /// Forwarded to the loading spinner's `CircularProgressIndicator.value`.
  /// Left `null` (indeterminate) for real usage; golden tests pin a fixed
  /// value so `pumpAndSettle` doesn't hang on a never-settling animation
  /// — see the equivalent note on `LoadingIndicator`.
  final double? loadingValue;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingValue,
              ),
            )
          : Text(label),
    );
  }
}
