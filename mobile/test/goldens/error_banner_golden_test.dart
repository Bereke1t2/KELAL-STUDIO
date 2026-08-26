import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/error_banner.dart';

import 'golden_helpers.dart';

/// Golden coverage for [ErrorBanner] — Figma Color Foundations,
/// `Color — Feedback` section, node `11:11` (the "Error" swatch of the
/// Success/Warning/Error/Info group at `11:4`), explicitly documented
/// in-file as powering "Toast/Banner and Badge components directly".
void main() {
  goldenThemeTest(
    'Error banner renders with a title, dismiss action, and Amharic copy',
    fileName: 'error_banner',
    surfaceSize: const Size(340, 140),
    variants: {
      'title + message - english': (context) => const ErrorBanner(
        title: 'Error',
        message: 'Generation failed. Try again.',
      ),
      'title + message - amharic': (context) => const ErrorBanner(
        title: 'ስህተት',
        message: 'ማመንጨት አልተሳካም። እንደገና ይሞክሩ።',
      ),
      'message only': (context) =>
          const ErrorBanner(message: 'Draft could not be saved.'),
      'dismissible': (context) => ErrorBanner(
        title: 'Error',
        message: 'Generation failed. Try again.',
        onDismiss: () {},
      ),
    },
  );
}
