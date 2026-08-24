import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/segmented_control.dart';

import 'golden_helpers.dart';

/// Golden coverage for [AppSegmentedControl]. **No dedicated Figma node
/// exists for this component** — see the doc comment on
/// `lib/core/widgets/segmented_control.dart` and the "Segmented Control"
/// row in `flutter-design-system/SKILL.md`'s node-id table for the
/// discrepancy this flags. Built from the same tokens `AppChip` uses.
void main() {
  goldenThemeTest(
    'Segmented control renders its selected segment',
    fileName: 'segmented_control',
    surfaceSize: const Size(320, 80),
    variants: {
      'english - first selected': (context) => AppSegmentedControl(
        labels: const ['Post', 'Story'],
        selectedIndex: 0,
        onChanged: (_) {},
      ),
      'amharic - second selected': (context) => AppSegmentedControl(
        labels: const ['ልጥፍ', 'ታሪክ'],
        selectedIndex: 1,
        onChanged: (_) {},
      ),
    },
  );
}
