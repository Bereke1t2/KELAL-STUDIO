import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/loading_indicator.dart';

import 'golden_helpers.dart';

/// Golden coverage for [LoadingIndicator] — Figma `Components / Loading
/// Indicator`, node `27:2` ("Type=Spinner, Size=Default").
///
/// `alchemist`'s default `pumpBeforeTest` is `pumpAndSettle`, which never
/// returns for an indeterminate (continuously-animating)
/// `CircularProgressIndicator` — every variant below pins `value` to a
/// fixed double so the widget renders one static, deterministic frame
/// instead of hanging the test. Real (non-golden) usage leaves `value`
/// unset, matching Figma's spinner intent.
void main() {
  goldenThemeTest(
    'Loading indicator renders with and without a caption',
    fileName: 'loading_indicator',
    surfaceSize: const Size(280, 100),
    variants: {
      'no caption': (context) => const LoadingIndicator(value: 0.65),
      'caption - english': (context) => const LoadingIndicator(
        value: 0.65,
        caption: 'Generating caption… (3s target)',
      ),
      'caption - amharic': (context) =>
          const LoadingIndicator(value: 0.65, caption: 'መግለጫ በመፍጠር ላይ…'),
    },
  );
}
