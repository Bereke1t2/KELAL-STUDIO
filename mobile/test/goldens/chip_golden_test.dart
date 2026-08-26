import 'package:kelal_studio/core/widgets/chip.dart';

import 'golden_helpers.dart';

/// Golden coverage for [AppChip] — Figma `Components / Chip` (documented
/// as "Badge" in-file), node `18:2` (Default) and `18:4` (Selected).
void main() {
  goldenThemeTest(
    'Chip renders its default and selected states',
    fileName: 'chip',
    variants: {
      'default - english': (context) => const AppChip(label: 'Coffee'),
      'default - amharic': (context) => const AppChip(label: 'ቡና'),
      'selected - english': (context) =>
          const AppChip(label: 'Coffee', selected: true),
      'selected - amharic': (context) =>
          const AppChip(label: 'ቡና', selected: true),
    },
  );
}
